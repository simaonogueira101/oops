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
    /// V1 history reads (HR/activity/stress/HRV) page in bursts with multi-second gaps between
    /// bursts; the default 8s per-packet timeout fires mid-stream and drops the whole read. A
    /// longer per-packet window lets all ~24 pages arrive so the data is parsed and persisted.
    private let historyPerPacketTimeout: Double = 15
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

            // Ring-facing time is LOCAL: the official app sets the ring clock to local BCD time.
            // RingHealthData also buckets by the local calendar, so everything stays aligned.
            let utc = Calendar.current

            // Full bind/init handshake — replicates the official app byte-for-byte (verified via
            // PacketLogger). This is what makes the ring grant the fast BLE connection interval
            // (an iOS central can't set it) and serve V1 history reliably. Order matters; all are
            // best-effort writes except battery (which we read).
            try? await transport.send(RingProtocol.phoneInfoCommand())                          // 04 01 1a
            try? await transport.send(RingProtocol.setTimeCommand(date: .now, calendar: utc))   // 01 setTime (local)
            try? await transport.send(RingProtocol.deviceSupportCommand())                      // 3c device-support
            try? await transport.send(RingProtocol.getConfig1Command())                         // 0a 01
            try? await transport.send(RingProtocol.getConfig2Command())                         // 0a 02 …
            try? await transport.send(RingProtocol.setPrefsCommand())                           // 19 01 01 01
            transport.fireAndForget(RingProtocol.bindSuccessCommand())                          // 10 BIND
            try? await Task.sleep(for: .milliseconds(200))
            do {                                                                                // 03 battery
                let response = try await transport.send(RingProtocol.batteryCommand())
                if let status = RingProtocol.parseBattery(response) {
                    let now = Date()
                    batteryStatus = status
                    lastUpdated = now
                    modelContext.insert(BatteryReading(timestamp: now, level: status.level, isCharging: status.isCharging))
                }
            } catch { trace("battery step failed: \(error)") }
            if transport.supportsBigData {                                                      // BC 30 handshake
                _ = try? await transport.sendBigData(RingBigData.handshakeRequest(),
                                                     isComplete: RingBigData.handshakeComplete)
            }
            // Monitoring enables (16/2c/36/38/21/3b/3a), exact bytes from the capture.
            try? await transport.send(RingProtocol.enableHRMonitorCommand())                    // 16 01 02
            try? await transport.send(RingProtocol.enableSpO2MonitorCommand())                  // 2c 01
            try? await transport.send(RingProtocol.enableStressMonitorCommand())                // 36 01
            try? await transport.send(RingProtocol.enableHRVMonitorCommand())                   // 38 01 02
            try? await transport.send(RingProtocol.goalsQueryCommand())                         // 21 01
            try? await transport.send(RingProtocol.enable3BCommand())                           // 3b 01 01
            try? await transport.send(RingProtocol.enableTempMonitorCommand())                  // 3a 03 01

            // Let the init responses fully drain before history. iOS batches notifications, so
            // the init replies otherwise dribble out DURING the first history read, congest its
            // channel, and make the paged reads time out. A short settle clears them first.
            try? await Task.sleep(for: .seconds(2))

            // History backfill (local day boundaries, matching the ring's local clock).
            let calendar = utc
            let today = calendar.startOfDay(for: .now)
            let meta = (try? syncMeta()) ?? RingSyncMeta()

            let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today

            // Per-day history backfill across the week. The official app loops all 7 days for
            // every metric on bind (HR by day-midnight timestamp; stress/HRV/activity by day
            // index). We do the same; timestamp dedup keeps re-fetched days from duplicating.
            // Today re-syncs every time (it's still accumulating); past days stop once stored.
            // HR uses a global-frame collector (see below), so it's not in this per-day loop.
            for metricKey in ["activity", "stress", "hrv"] {
                let lastSynced = meta.lastSyncedDay[metricKey]
                let from: Date
                if let last = lastSynced, !force {
                    from = calendar.date(byAdding: .day, value: 1, to: last) ?? weekStart
                } else {
                    from = weekStart
                }
                let clampedFrom = max(from, weekStart)
                guard clampedFrom <= today else { continue }

                var existingTimestamps = fetchTimestampsForMetric(metricKey)
                var day = clampedFrom
                while day <= today {
                    let dayOffset = calendar.dateComponents([.day], from: day, to: today).day ?? 0
                    do {
                        try await syncDayThrowing(day: day, dayOffset: dayOffset, metricKey: metricKey,
                                                   calendar: calendar, existingTimestamps: &existingTimestamps)
                        meta.lastSyncedDay[metricKey] = day
                    } catch {
                        trace("\(metricKey) history day=\(day) failed: \(error) — stopping this metric")
                        break
                    }
                    // Pace queries so the ring (and iOS's notification batching) isn't overrun;
                    // back-to-back paged reads on this connection drop responses.
                    try? await Task.sleep(for: .milliseconds(200))
                    day = calendar.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(86400)
                }
            }

            // HR history via GLOBAL FRAME COLLECTOR. The ring delivers a day's 24 packets slowly
            // and out of step with per-read windows (the data for one day lands during the next
            // day's read), so per-day paged reads capture only the header. Instead, fire all 7
            // day queries and gather EVERY 0x15 frame over a long window, then split the stream
            // into day-runs at each header (sub_type 0) and parse each independently.
            do {
                let hrQueries: [Data] = (0..<7).compactMap { offset in
                    calendar.date(byAdding: .day, value: -offset, to: today)
                        .map { RingProtocol.heartRateHistoryCommand(day: $0, calendar: calendar) }
                }
                var existingHR = fetchTimestampsForMetric("hr")
                var totalInserted = 0
                // Dynamic widening: keep running gather rounds while each one still adds NEW
                // samples (the connection trickles data slowly, so a round often catches frames
                // the previous one missed). Stop when a round adds nothing new, or after a few
                // rounds. Each gather itself also self-extends while frames keep arriving.
                for round in 0..<4 {
                    let frames = await transport.gather(commands: hrQueries, opcode: 0x15,
                                                        gap: 1.5, quietPeriod: 8.0, maxWindow: 60.0)
                    var run: [Data] = []
                    var inserted = 0
                    func flushRun() {
                        guard !run.isEmpty else { return }
                        for s in RingProtocol.parseHeartRateHistory(run) where !existingHR.contains(s.date) {
                            modelContext.insert(HeartRateSample(timestamp: s.date, bpm: Int(s.value)))
                            existingHR.insert(s.date); inserted += 1
                        }
                        run = []
                    }
                    for f in frames {
                        let sub = f.count > 1 ? f[f.startIndex + 1] : 0xFF
                        if sub == 0 { flushRun() }   // header → start of a new day's run
                        run.append(f)
                    }
                    flushRun()
                    totalInserted += inserted
                    trace("hr gather round \(round): \(frames.count) frames → +\(inserted) new (\(totalInserted) total)")
                    if inserted == 0 { break }   // round added nothing new → data is exhausted
                }
                if totalInserted > 0 { meta.lastSyncedDay["hr"] = today }
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

            // Drain late V2 responses. SpO2's large response often arrives AFTER its own read
            // timed out (during the next read); the transport caches mismatched-action frames so
            // we can recover them here instead of losing them.
            if transport.supportsBigData {
                let lateSpo2 = transport.takeCachedBigData(0x2A)
                if !lateSpo2.isEmpty {
                    let samples = RingBigData.parseSpO2(lateSpo2, today: .now, calendar: utc)
                    let existing = (try? fetchTimestamps(SpO2Sample.self)) ?? []
                    for s in samples where !existing.contains(s.date) {
                        modelContext.insert(SpO2Sample(timestamp: s.date, percent: Int(s.value)))
                    }
                    if !samples.isEmpty { meta.lastSyncedDay["spo2"] = today }
                    trace("spo2 drained \(samples.count) samples from cache")
                }
                let lateTemp = transport.takeCachedBigData(0x25)
                if !lateTemp.isEmpty {
                    let readings = RingBigData.parseTemperature(lateTemp, today: .now, calendar: utc)
                    let existing = (try? fetchTimestamps(TemperatureSample.self)) ?? []
                    for r in readings where !existing.contains(r.date) {
                        modelContext.insert(TemperatureSample(timestamp: r.date, celsius: r.celsius))
                    }
                    trace("temp drained \(readings.count) readings from cache")
                }
            }

            // Live HR LAST — after the full init/history handshake, when the connection is warm.
            // The official app sends NO keepalive (verified via PacketLogger): the ring auto-
            // streams 0x69 echo frames ~0.5s apart after the start; we just listen until a
            // non-zero BPM (byte[3], byte[2]==0) or a frame cap, then stop.
            do {
                let frames = try await transport.send(
                    RingProtocol.liveHRStartCommand(),
                    isComplete: { packets in
                        packets.contains { RingProtocol.parseLiveHR($0) != nil } || packets.count >= 70
                    },
                    perPacketTimeout: 12
                )
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
                isComplete: RingProtocol.heartRateHistoryComplete,
                perPacketTimeout: historyPerPacketTimeout
            )
            let samples = RingProtocol.parseHeartRateHistory(packets)
            trace("hr: \(packets.count) packets → \(samples.count) samples (first bpm \(samples.first.map { Int($0.value) } ?? -1))")
            for s in samples where !existingTimestamps.contains(s.date) {
                modelContext.insert(HeartRateSample(timestamp: s.date, bpm: Int(s.value)))
                existingTimestamps.insert(s.date)
            }

        case "activity":
            let packets = try await transport.send(
                RingProtocol.activityHistoryCommand(dayOffset: dayOffset),
                isComplete: RingProtocol.activityHistoryComplete,
                perPacketTimeout: historyPerPacketTimeout
            )
            let samples = RingProtocol.parseActivityHistory(packets, calendar: calendar)
            for s in samples where !existingTimestamps.contains(s.date) {
                modelContext.insert(ActivitySample(timestamp: s.date, steps: s.steps,
                                                   calories: s.calories, distanceMeters: s.distanceMeters))
                existingTimestamps.insert(s.date)
            }

        case "stress":
            let packets = try await transport.send(
                RingProtocol.stressHistoryCommand(dayOffset: dayOffset),
                isComplete: RingProtocol.stressHistoryComplete,
                perPacketTimeout: historyPerPacketTimeout
            )
            let samples = RingProtocol.parseStress(packets, dayStart: dayStart)
            for s in samples where !existingTimestamps.contains(s.date) {
                modelContext.insert(StressSample(timestamp: s.date, value: Int(s.value)))
                existingTimestamps.insert(s.date)
            }

        case "hrv":
            let packets = try await transport.send(
                RingProtocol.hrvHistoryCommand(dayOffset: dayOffset),
                isComplete: RingProtocol.hrvHistoryComplete,
                perPacketTimeout: historyPerPacketTimeout
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
