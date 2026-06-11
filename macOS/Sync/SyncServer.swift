import Foundation
import Network
import Observation

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
}
