import Foundation
import Network
import Observation

enum SyncState: Sendable { case idle, searching, sent, failed }

/// Finds the Mac's Bonjour service on the LAN and pushes a payload to it.
final class SyncClient: @unchecked Sendable {
    private let queue = DispatchQueue(label: "oops.sync.client")
    private var browser: NWBrowser?
    private let onState: @Sendable (SyncState) -> Void

    init(onState: @escaping @Sendable (SyncState) -> Void) { self.onState = onState }

    func push(_ payload: SyncPayload) {
        queue.async { [self] in
            onState(.searching)
            browser?.cancel()
            let browser = NWBrowser(for: .bonjour(type: OopsSync.serviceType, domain: nil), using: .tcp)
            self.browser = browser
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard let self, let endpoint = results.first?.endpoint else { return }
                self.browser?.cancel()
                OutgoingConn(endpoint: endpoint, queue: self.queue, onState: self.onState).send(payload)
            }
            browser.start(queue: queue)
        }
    }
}

/// One outbound connection that sends a single newline-terminated JSON payload.
private final class OutgoingConn: @unchecked Sendable {
    private let conn: NWConnection
    private let onState: @Sendable (SyncState) -> Void

    init(endpoint: NWEndpoint, queue: DispatchQueue, onState: @escaping @Sendable (SyncState) -> Void) {
        self.conn = NWConnection(to: endpoint, using: .tcp)
        self.onState = onState
        conn.start(queue: queue)
    }

    func send(_ payload: SyncPayload) {
        conn.stateUpdateHandler = { [self] state in
            switch state {
            case .ready:
                guard var data = OopsSync.encode(payload) else { onState(.failed); conn.cancel(); return }
                data.append(0x0A)
                conn.send(content: data, completion: .contentProcessed { [self] _ in
                    onState(.sent); conn.cancel()
                })
            case .failed, .cancelled:
                conn.cancel()
            default:
                break
            }
        }
    }
}

/// Main-actor, observable sender the UI binds to.
@MainActor
@Observable
final class SyncCoordinator {
    var state: SyncState = .idle
    var lastSync: Date?

    @ObservationIgnored
    private lazy var client = SyncClient { [weak self] newState in
        Task { @MainActor in
            self?.state = newState
            if newState == .sent { self?.lastSync = Date() }
        }
    }

    func push(_ readings: [BatteryDTO]) {
        client.push(SyncPayload(source: OopsSync.deviceName, battery: readings))
    }
}
