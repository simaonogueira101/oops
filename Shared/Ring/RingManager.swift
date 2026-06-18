import Foundation
import SwiftData

/// Orchestrates a full sync session: connect → set time → battery → live HR →
/// 7-day history backfill (HR/activity/sleep/stress/SpO2) → temperature → disconnect.
/// Transport-agnostic (injected `RingTransport`), so it runs identically against the
/// mock or, later, real CoreBluetooth.
@MainActor
@Observable
final class RingManager {
    private let transport: any RingTransport
    private let modelContext: ModelContext

    var batteryStatus: BatteryStatus?
    var lastUpdated: Date?
    var isBusy = false
    var errorMessage: String?
    /// Distinct from a generic error: Bluetooth itself is off/unauthorized, so the UI can
    /// point the user at Settings rather than offer a plain "try again".
    var bluetoothUnavailable = false
    /// Most recent live heart-rate reading from the ring (BPM).
    var liveHR: Int?

    init(transport: any RingTransport, modelContext: ModelContext) {
        self.transport = transport
        self.modelContext = modelContext
    }

    // MARK: Ring binding

    /// Returns the single `RingSyncMeta` record, creating and inserting one if none exists.
    private func syncMeta() throws -> RingSyncMeta {
        let existing = try modelContext.fetch(FetchDescriptor<RingSyncMeta>())
        if let meta = existing.first { return meta }
        let meta = RingSyncMeta()
        modelContext.insert(meta)
        return meta
    }

    // MARK: - Full sync session

    func sync() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        bluetoothUnavailable = false
        defer { isBusy = false }

        do {
            // Apply any existing ring binding before connecting.
            if let meta = try? syncMeta() {
                transport.boundRingID = meta.boundRingID.flatMap(UUID.init(uuidString:))
            }

            try await transport.connect()

            // After the first successful connect, persist the binding.
            if let meta = try? syncMeta(), meta.boundRingID == nil,
               let connectedID = transport.connectedRingID {
                meta.boundRingID = connectedID.uuidString
                meta.boundRingName = transport.connectedRingName
                try? modelContext.save()
            }

            // a. Set clock (best-effort)
            try? await transport.send(RingProtocol.setTimeCommand(date: .now, calendar: .current))

            // b. Battery
            do {
                let response = try await transport.send(RingProtocol.batteryCommand())
                if let status = RingProtocol.parseBattery(response) {
                    let now = Date()
                    batteryStatus = status
                    lastUpdated = now
                    modelContext.insert(BatteryReading(timestamp: now, level: status.level, isCharging: status.isCharging))
                }
            } catch {
                trace("battery step failed: \(error)")
            }

            // c. Live HR
            do {
                let packets = try await transport.send(
                    RingProtocol.liveHRStartCommand(),
                    isComplete: { packets in packets.contains { RingProtocol.parseLiveHR($0) != nil } }
                )
                if let bpm = packets.compactMap({ RingProtocol.parseLiveHR($0) }).first {
                    liveHR = bpm
                }
                try? await transport.send(RingProtocol.liveHRStopCommand())
            } catch {
                trace("liveHR step failed: \(error)")
            }

            // d. History backfill
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            let meta = (try? syncMeta()) ?? RingSyncMeta()

            let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today

            for metricKey in ["hr", "activity", "sleep", "stress", "spo2"] {
                let lastSynced = meta.lastSyncedDay[metricKey]
                let from: Date
                if let last = lastSynced {
                    from = calendar.date(byAdding: .day, value: 1, to: last) ?? weekStart
                } else {
                    from = weekStart
                }
                // Clamp to at most 7 days back
                let clampedFrom = max(from, weekStart)
                guard clampedFrom <= today else { continue }

                var day = clampedFrom
                while day <= today {
                    let dayOffset = calendar.dateComponents([.day], from: day, to: today).day ?? 0
                    await syncDay(day: day, dayOffset: dayOffset, metricKey: metricKey,
                                  calendar: calendar, meta: meta, today: today)
                    day = calendar.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(86400)
                }
            }

            // e. Temperature (Big Data V2)
            if transport.supportsBigData {
                do {
                    try? await transport.send(RingProtocol.enableAllDayTemperatureCommand())
                    let packets = try await transport.sendBigData(
                        RingBigData.temperatureRequest(),
                        isComplete: RingBigData.temperatureComplete
                    )
                    let readings = RingBigData.parseTemperature(packets, today: .now, calendar: .current)
                    let existing = (try? fetchTimestamps(TemperatureSample.self)) ?? []
                    for r in readings where !existing.contains(r.date) {
                        modelContext.insert(TemperatureSample(timestamp: r.date, celsius: r.celsius))
                    }
                    if !readings.isEmpty {
                        meta.lastSyncedDay["temperature"] = today
                    }
                } catch {
                    trace("temperature step failed: \(error)")
                }
            }

            // f. Disconnect
            transport.disconnect()

            // g. Save
            try? modelContext.save()

        } catch let error as RingError {
            transport.disconnect()
            apply(error)
        } catch {
            transport.disconnect()
            errorMessage = "Couldn't connect to the ring."
        }
    }

    // MARK: - Per-day metric sync (partial-failure tolerant)

    private func syncDay(day: Date, dayOffset: Int, metricKey: String,
                         calendar: Calendar, meta: RingSyncMeta, today: Date) async {
        let dayStart = calendar.startOfDay(for: day)

        switch metricKey {
        case "hr":
            do {
                let packets = try await transport.send(
                    RingProtocol.heartRateHistoryCommand(day: day, calendar: calendar),
                    isComplete: RingProtocol.heartRateHistoryComplete
                )
                let samples = RingProtocol.parseHeartRateHistory(packets)
                let existing = (try? fetchTimestamps(HeartRateSample.self)) ?? []
                for s in samples where !existing.contains(s.date) {
                    modelContext.insert(HeartRateSample(timestamp: s.date, bpm: Int(s.value)))
                }
                if !samples.isEmpty { meta.lastSyncedDay["hr"] = today }
            } catch {
                trace("HR history day=\(day) failed: \(error)")
            }

        case "activity":
            do {
                let packets = try await transport.send(
                    RingProtocol.activityHistoryCommand(dayOffset: dayOffset),
                    isComplete: RingProtocol.activityHistoryComplete
                )
                let samples = RingProtocol.parseActivityHistory(packets, calendar: calendar)
                let existing = (try? fetchTimestamps(ActivitySample.self)) ?? []
                for s in samples where !existing.contains(s.date) {
                    modelContext.insert(ActivitySample(timestamp: s.date, steps: s.steps,
                                                       calories: s.calories, distanceMeters: s.distanceMeters))
                }
                if !samples.isEmpty { meta.lastSyncedDay["activity"] = today }
            } catch {
                trace("activity history day=\(day) failed: \(error)")
            }

        case "sleep":
            do {
                let packets = try await transport.send(
                    RingProtocol.sleepHistoryCommand(day: day, calendar: calendar),
                    isComplete: RingProtocol.sleepHistoryComplete
                )
                let intervals = RingProtocol.parseSleep(packets, dayStart: dayStart)
                if !intervals.isEmpty {
                    // Delete existing record for this dayStart to avoid duplicates.
                    let existing = try modelContext.fetch(
                        FetchDescriptor<SleepSessionRecord>(
                            predicate: #Predicate { $0.dayStart == dayStart }
                        )
                    )
                    for record in existing { modelContext.delete(record) }

                    let stageRecords = intervals.map { iv in
                        SleepStageIntervalRecord(
                            stageRaw: stageRaw(for: iv.stage),
                            start: iv.start,
                            end: iv.end
                        )
                    }
                    modelContext.insert(SleepSessionRecord(dayStart: dayStart, intervals: stageRecords))
                    meta.lastSyncedDay["sleep"] = today
                }
            } catch {
                trace("sleep history day=\(day) failed: \(error)")
            }

        case "stress":
            do {
                let packets = try await transport.send(
                    RingProtocol.stressHistoryCommand(day: day, calendar: calendar),
                    isComplete: RingProtocol.stressHistoryComplete
                )
                let samples = RingProtocol.parseStress(packets, dayStart: dayStart)
                let existing = (try? fetchTimestamps(StressSample.self)) ?? []
                for s in samples where !existing.contains(s.date) {
                    modelContext.insert(StressSample(timestamp: s.date, value: Int(s.value)))
                }
                if !samples.isEmpty { meta.lastSyncedDay["stress"] = today }
            } catch {
                trace("stress history day=\(day) failed: \(error)")
            }

        case "spo2":
            do {
                let packets = try await transport.send(
                    RingProtocol.spo2HistoryCommand(day: day, calendar: calendar),
                    isComplete: RingProtocol.spo2HistoryComplete
                )
                let samples = RingProtocol.parseSpO2History(packets, dayStart: dayStart)
                let existing = (try? fetchTimestamps(SpO2Sample.self)) ?? []
                for s in samples where !existing.contains(s.date) {
                    modelContext.insert(SpO2Sample(timestamp: s.date, percent: Int(s.value)))
                }
                if !samples.isEmpty { meta.lastSyncedDay["spo2"] = today }
            } catch {
                trace("SpO2 history day=\(day) failed: \(error)")
            }

        default: break
        }
    }

    // MARK: - Helpers

    /// Fetches all timestamps already stored for a given `@Model` sample type.
    private func fetchTimestamps<T: PersistentModel & HasTimestamp>(_ type: T.Type) throws -> Set<Date> {
        let all = try modelContext.fetch(FetchDescriptor<T>())
        return Set(all.map(\.timestamp))
    }

    /// Maps a `SleepStage` to the integer convention used in `SleepStageIntervalRecord`.
    /// Matches `SleepStage.row`: awake=0, rem=1, light=2, deep=3.
    private func stageRaw(for stage: SleepStage) -> Int {
        switch stage {
        case .awake: return 0
        case .rem:   return 1
        case .light: return 2
        case .deep:  return 3
        }
    }

    private func trace(_ message: String) {
        // Structured logging stub; replace with os.Logger in a future task.
        print("[RingManager] \(message)")
    }

    /// Maps a transport error to a specific, user-facing state.
    private func apply(_ error: RingError) {
        switch error {
        case .bluetoothUnavailable:
            bluetoothUnavailable = true
            errorMessage = "Bluetooth is off. Turn it on to reach your ring."
        case .ringNotFound:
            errorMessage = "Ring not found. Make sure it's nearby and try again."
        case .timeout:
            errorMessage = "The ring didn't respond. Try again."
        case .connectionFailed, .notConnected:
            errorMessage = "Couldn't connect to the ring. Try again."
        case .unsupportedCommand:
            errorMessage = "Couldn't read the ring's battery."
        }
    }

    // MARK: - Legacy alias

    /// Kept for source compatibility with any call sites not yet migrated to `sync()`.
    @available(*, deprecated, renamed: "sync")
    func refreshBattery() async { await sync() }
}

// MARK: - HasTimestamp protocol

/// Common timestamp accessor used by the generic upsert helper.
protocol HasTimestamp {
    var timestamp: Date { get }
}

extension HeartRateSample: HasTimestamp {}
extension ActivitySample: HasTimestamp {}
extension SpO2Sample: HasTimestamp {}
extension StressSample: HasTimestamp {}
extension TemperatureSample: HasTimestamp {}
