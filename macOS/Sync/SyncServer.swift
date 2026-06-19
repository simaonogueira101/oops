import Foundation
import Network
import Observation
import SwiftData

/// Low-level Bonjour listener. Networking runs on a background queue; decoded payloads
/// are delivered through a @Sendable callback (which hops to the main actor in SyncInbox).
final class SyncServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "oops.sync.server")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: IncomingConn] = [:]
    private let onPayload: @Sendable (SyncPayload) -> Void

    init(onPayload: @escaping @Sendable (SyncPayload) -> Void) {
        self.onPayload = onPayload
    }

    func start() {
        queue.async { [self] in
            guard listener == nil else { return }
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            guard let listener = try? NWListener(using: params) else { return }
            listener.service = NWListener.Service(type: OopsSync.serviceType)
            listener.newConnectionHandler = { [weak self] conn in
                guard let self else { return }
                let incoming = IncomingConn(conn, queue: self.queue, onPayload: self.onPayload) { [weak self] id in
                    self?.queue.async { self?.connections[id] = nil }
                }
                self.connections[ObjectIdentifier(incoming)] = incoming
                incoming.start()
            }
            listener.start(queue: queue)
            self.listener = listener
        }
    }
}

/// One inbound connection, accumulating newline-delimited JSON.
private final class IncomingConn: @unchecked Sendable {
    private let conn: NWConnection
    private let queue: DispatchQueue
    private let onPayload: @Sendable (SyncPayload) -> Void
    private let onDone: @Sendable (ObjectIdentifier) -> Void
    private var buffer = Data()

    init(_ conn: NWConnection, queue: DispatchQueue,
         onPayload: @escaping @Sendable (SyncPayload) -> Void,
         onDone: @escaping @Sendable (ObjectIdentifier) -> Void) {
        self.conn = conn; self.queue = queue; self.onPayload = onPayload; self.onDone = onDone
    }

    func start() {
        conn.start(queue: queue)
        receive()
    }

    private func receive() {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [self] data, _, isComplete, error in
            if let data { buffer.append(data) }
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[buffer.startIndex..<nl])
                buffer.removeSubrange(buffer.startIndex...nl)
                if let payload = OopsSync.decode(line) { onPayload(payload) }
            }
            if isComplete || error != nil {
                conn.cancel()
                onDone(ObjectIdentifier(self))
            } else {
                receive()
            }
        }
    }
}

/// Main-actor, observable receiver the UI binds to.
@MainActor
@Observable
final class SyncInbox {
    var lastPayload: SyncPayload?
    var lastSync: Date?
    @ObservationIgnored var modelContext: ModelContext?
    private var server: SyncServer?

    func start() {
        guard server == nil else { return }
        let server = SyncServer { [weak self] payload in
            Task { @MainActor in self?.receive(payload) }
        }
        self.server = server
        server.start()
    }

    private func receive(_ payload: SyncPayload) {
        lastPayload = payload
        lastSync = Date()
        ingest(payload)

        // Append to a log for debugging / verification.
        let dir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/Oops")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = (dir as NSString).appendingPathComponent("sync.log")
        let line = "received from \(payload.source): \(payload.latestLevel ?? -1)% · \(payload.battery.count) readings\n"
        if let data = line.data(using: .utf8) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }
    }

    /// Persists synced rows into the Mac's local store, mirroring the iPhone's RingManager:
    /// timestamp-dedup per sample type, and per-`dayStart` upsert for sleep.
    private func ingest(_ payload: SyncPayload) {
        guard let modelContext else { return }

        insertDeduped(payload.heartRate, type: HeartRateSample.self, key: \.timestamp,
                      stamp: \.timestamp) { HeartRateSample(timestamp: $0.timestamp, bpm: $0.bpm) }
        insertDeduped(payload.hrv, type: HRVSample.self, key: \.timestamp,
                      stamp: \.timestamp) { HRVSample(timestamp: $0.timestamp, value: $0.value) }
        insertDeduped(payload.spo2, type: SpO2Sample.self, key: \.timestamp,
                      stamp: \.timestamp) { SpO2Sample(timestamp: $0.timestamp, percent: $0.percent) }
        insertDeduped(payload.stress, type: StressSample.self, key: \.timestamp,
                      stamp: \.timestamp) { StressSample(timestamp: $0.timestamp, value: $0.value) }
        insertDeduped(payload.temperature, type: TemperatureSample.self, key: \.timestamp,
                      stamp: \.timestamp) { TemperatureSample(timestamp: $0.timestamp, celsius: $0.celsius) }
        insertDeduped(payload.activity, type: ActivitySample.self, key: \.timestamp,
                      stamp: \.timestamp) {
            ActivitySample(timestamp: $0.timestamp, steps: $0.steps,
                           calories: $0.calories, distanceMeters: $0.distanceMeters)
        }
        insertDeduped(payload.battery, type: BatteryReading.self, key: \.timestamp,
                      stamp: \.timestamp) {
            BatteryReading(timestamp: $0.timestamp, level: $0.level, isCharging: $0.isCharging)
        }

        // Sleep: replace any existing session for the same day, then insert the new one.
        for session in payload.sleep {
            let dayStart = session.dayStart
            let existing = (try? modelContext.fetch(
                FetchDescriptor<SleepSessionRecord>(predicate: #Predicate { $0.dayStart == dayStart })
            )) ?? []
            for record in existing { modelContext.delete(record) }
            let intervals = session.intervals.map {
                SleepStageIntervalRecord(stageRaw: $0.stageRaw, start: $0.start, end: $0.end)
            }
            modelContext.insert(SleepSessionRecord(dayStart: dayStart, intervals: intervals))
        }

        try? modelContext.save()
    }

    /// Inserts only DTOs whose timestamp isn't already stored for `Model`.
    private func insertDeduped<DTO, Model: PersistentModel>(
        _ dtos: [DTO],
        type: Model.Type,
        key: KeyPath<Model, Date>,
        stamp: KeyPath<DTO, Date>,
        make: (DTO) -> Model
    ) {
        guard let modelContext, !dtos.isEmpty else { return }
        let existing = (try? modelContext.fetch(FetchDescriptor<Model>())) ?? []
        var seen = Set(existing.map { $0[keyPath: key] })
        for dto in dtos {
            let ts = dto[keyPath: stamp]
            guard !seen.contains(ts) else { continue }
            modelContext.insert(make(dto))
            seen.insert(ts)
        }
    }
}
