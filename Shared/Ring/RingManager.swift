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

    /// Runs a full sync session. `force: true` re-pulls all available history (the ring's full
    /// ~7-day window) instead of only the days not yet synced — used by the manual sync button.
    func sync(force: Bool = false) async {
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

            // a. Bind FIRST — register this phone as the ring's bound host (CMD_BIND_SUCCESS).
            // The official app sends this on its "bind a device" step, and the ring gates
            // real-time streaming (live HR) and history logging (sleep/HRV) on being bound.
            // Fire-and-forget (the ring doesn't reply), then a brief pause so it's processed
            // before we start reading.
            trace("Sending bind (0x10 CMD_BIND_SUCCESS)")
            transport.fireAndForget(RingProtocol.bindSuccessCommand())
            try? await Task.sleep(for: .milliseconds(300))

            // Ring-facing time is UTC (tahnok convention): clock set in UTC, history requested
            // at UTC midnights. Sample timestamps come back as absolute instants; the display
            // layer (RingHealthData) buckets them by the local calendar.
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!

            // b. Set clock (best-effort)
            try? await transport.send(RingProtocol.setTimeCommand(date: .now, calendar: utc))

            // a2. Enable HR logging (best-effort; harmless to repeat each sync)
            try? await transport.send(RingProtocol.enableHeartRateLoggingCommand())

            // a3. Enable HRV measurement (best-effort; harmless to repeat each sync)
            try? await transport.send(RingProtocol.enableHRVCommand())

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

            // c. Init handshake — match the official app: query device support (0x3C) and run the
            // BC 30 big-data handshake. This appears to put the ring into its real-time-capable
            // state, the state in which it asks iOS for the fast BLE connection interval that
            // live-HR streaming requires (a central can't set the interval itself on iOS).
            try? await transport.send(RingProtocol.deviceSupportCommand())
            if transport.supportsBigData {
                _ = try? await transport.sendBigData(RingBigData.handshakeRequest(),
                                                     isComplete: RingBigData.handshakeComplete)
            }

            // History backfill (UTC day boundaries to match the ring's UTC clock)
            let calendar = utc
            let today = calendar.startOfDay(for: .now)
            let meta = (try? syncMeta()) ?? RingSyncMeta()

            let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today

            // SpO2 and sleep are now fetched via Big Data V2 after the per-day loop.
            for metricKey in ["hr", "activity", "stress", "hrv"] {
                let lastSynced = meta.lastSyncedDay[metricKey]
                let from: Date
                if let last = lastSynced, !force {
                    from = calendar.date(byAdding: .day, value: 1, to: last) ?? weekStart
                } else {
                    // Force sync (or first sync) re-pulls the whole window. Dedup by timestamp
                    // keeps re-fetched days from creating duplicates.
                    from = weekStart
                }
                // Clamp to at most 7 days back
                let clampedFrom = max(from, weekStart)
                guard clampedFrom <= today else { continue }

                // Fetch existing timestamps once per metric (avoids full-table scan per day).
                var existingTimestamps: Set<Date> = fetchTimestampsForMetric(metricKey)

                var day = clampedFrom
                while day <= today {
                    let dayOffset = calendar.dateComponents([.day], from: day, to: today).day ?? 0
                    do {
                        try await syncDayThrowing(day: day, dayOffset: dayOffset, metricKey: metricKey,
                                                   calendar: calendar,
                                                   existingTimestamps: &existingTimestamps)
                        // Advance per-day on success (empty result also counts as success).
                        meta.lastSyncedDay[metricKey] = day
                    } catch {
                        trace("\(metricKey) history day=\(day) failed: \(error) — stopping this metric for this sync")
                        break  // Stop advancing this metric; retry from this day next sync.
                    }
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
                    let readings = RingBigData.parseTemperature(packets, today: .now, calendar: utc)
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

            // f. SpO2 V2 (Big Data 0x2A) — replaces the V1 per-day spo2HistoryCommand
            if transport.supportsBigData {
                do {
                    try? await transport.send(RingProtocol.enableAllDaySpO2Command())
                    let packets = try await transport.sendBigData(
                        RingBigData.spo2Request(),
                        isComplete: RingBigData.spo2Complete
                    )
                    let samples = RingBigData.parseSpO2(packets, today: .now, calendar: utc)
                    let existing = (try? fetchTimestamps(SpO2Sample.self)) ?? []
                    for s in samples where !existing.contains(s.date) {
                        modelContext.insert(SpO2Sample(timestamp: s.date, percent: Int(s.value)))
                    }
                    if !samples.isEmpty {
                        meta.lastSyncedDay["spo2"] = today
                    }
                } catch {
                    trace("spo2 V2 step failed: \(error)")
                }
            }

            // g. Sleep V2 (Big Data 0x27) — replaces the V1 per-day sleepHistoryCommand
            if transport.supportsBigData {
                do {
                    let packets = try await transport.sendBigData(
                        RingBigData.sleepRequest(),
                        isComplete: RingBigData.sleepComplete
                    )
                    let intervals = RingBigData.parseSleep(packets, today: .now, calendar: utc)
                    // Group intervals by dayStart and replace/insert one SleepSessionRecord per day.
                    let grouped = Dictionary(grouping: intervals) { iv in
                        utc.startOfDay(for: iv.start)
                    }
                    for (dayStart, dayIntervals) in grouped {
                        let existing = try modelContext.fetch(
                            FetchDescriptor<SleepSessionRecord>(
                                predicate: #Predicate { $0.dayStart == dayStart }
                            )
                        )
                        for record in existing { modelContext.delete(record) }
                        let stageRecords = dayIntervals.map { iv in
                            SleepStageIntervalRecord(
                                stageRaw: stageRaw(for: iv.stage),
                                start: iv.start,
                                end: iv.end
                            )
                        }
                        modelContext.insert(SleepSessionRecord(dayStart: dayStart, intervals: stageRecords))
                    }
                    if !intervals.isEmpty {
                        meta.lastSyncedDay["sleep"] = today
                    }
                } catch {
                    trace("sleep V2 step failed: \(error)")
                }
            }

            // Live HR LAST — the official app does its live read after the full init/history
            // handshake, when the connection is warm and active (PacketLogger showed the ring
            // streams ~60 frames at a fast interval in that state, vs one frame from a cold
            // connection). Collect 0x69 frames until a non-zero BPM (byte[3], byte[2]==0) or cap.
            do {
                transport.startKeepalive(RingProtocol.liveHRKeepaliveCommand(), interval: 0.8)
                defer { transport.stopKeepalive() }
                let frames = try await transport.send(
                    RingProtocol.liveHRStartCommand(),
                    isComplete: { packets in
                        packets.contains { RingProtocol.parseLiveHR($0) != nil } || packets.count >= 70
                    },
                    perPacketTimeout: 12
                )
                transport.stopKeepalive()
                if let bpm = frames.compactMap({ RingProtocol.parseLiveHR($0) }).first {
                    liveHR = bpm
                }
                try? await transport.send(RingProtocol.liveHRStopCommand())
            } catch {
                trace("liveHR step failed: \(error)")
                try? await transport.send(RingProtocol.liveHRStopCommand())
            }

            // h. Disconnect
            transport.disconnect()

            // i. Save
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

    /// Throws on transport/parse failure so the caller can break out of the day loop
    /// and retry from this day on the next sync.
    private func syncDayThrowing(day: Date, dayOffset: Int, metricKey: String,
                                  calendar: Calendar,
                                  existingTimestamps: inout Set<Date>) async throws {
        let dayStart = calendar.startOfDay(for: day)

        switch metricKey {
        case "hr":
            let packets = try await transport.send(
                RingProtocol.heartRateHistoryCommand(day: day, calendar: calendar),
                isComplete: RingProtocol.heartRateHistoryComplete
            )
            let samples = RingProtocol.parseHeartRateHistory(packets)
            for s in samples where !existingTimestamps.contains(s.date) {
                modelContext.insert(HeartRateSample(timestamp: s.date, bpm: Int(s.value)))
                existingTimestamps.insert(s.date)
            }

        case "activity":
            let packets = try await transport.send(
                RingProtocol.activityHistoryCommand(dayOffset: dayOffset),
                isComplete: RingProtocol.activityHistoryComplete
            )
            let samples = RingProtocol.parseActivityHistory(packets, calendar: calendar)
            for s in samples where !existingTimestamps.contains(s.date) {
                modelContext.insert(ActivitySample(timestamp: s.date, steps: s.steps,
                                                   calories: s.calories, distanceMeters: s.distanceMeters))
                existingTimestamps.insert(s.date)
            }

        case "stress":
            let packets = try await transport.send(
                RingProtocol.stressHistoryCommand(day: day, calendar: calendar),
                isComplete: RingProtocol.stressHistoryComplete
            )
            let samples = RingProtocol.parseStress(packets, dayStart: dayStart)
            for s in samples where !existingTimestamps.contains(s.date) {
                modelContext.insert(StressSample(timestamp: s.date, value: Int(s.value)))
                existingTimestamps.insert(s.date)
            }

        case "hrv":
            let packets = try await transport.send(
                RingProtocol.hrvHistoryCommand(day: day, calendar: calendar),
                isComplete: RingProtocol.hrvHistoryComplete
            )
            let samples = RingProtocol.parseHRV(packets, dayStart: dayStart)
            for s in samples where !existingTimestamps.contains(s.date) {
                modelContext.insert(HRVSample(timestamp: s.date, value: Int(s.value)))
                existingTimestamps.insert(s.date)
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

    /// Returns the existing persisted timestamps for a metric key (non-throwing; falls back to empty).
    /// Called once per metric before the day loop to avoid per-day full-table scans.
    private func fetchTimestampsForMetric(_ metricKey: String) -> Set<Date> {
        switch metricKey {
        case "hr":       return (try? fetchTimestamps(HeartRateSample.self)) ?? []
        case "activity": return (try? fetchTimestamps(ActivitySample.self)) ?? []
        case "stress":   return (try? fetchTimestamps(StressSample.self)) ?? []
        case "spo2":     return (try? fetchTimestamps(SpO2Sample.self)) ?? []
        case "hrv":      return (try? fetchTimestamps(HRVSample.self)) ?? []
        default:         return []
        }
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
extension HRVSample: HasTimestamp {}
