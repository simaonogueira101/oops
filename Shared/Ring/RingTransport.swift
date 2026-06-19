import Foundation

/// Errors surfaced by a ring transport. `RingManager` maps each to a distinct,
/// user-facing state (the spec's "Bluetooth unavailable", "ring not found", etc.).
enum RingError: Error, Equatable {
    case unsupportedCommand
    case notConnected
    /// Bluetooth is off, unauthorized, or unsupported on this device.
    case bluetoothUnavailable
    /// No ring advertising our service was found within the scan timeout.
    case ringNotFound
    /// Connecting to the ring or discovering its characteristics failed.
    case connectionFailed
    /// The ring connected but didn't answer the command in time.
    case timeout
}

/// The swappable seam between the app and the ring. Implemented by `MockRingTransport`
/// (simulated, used before the ring arrives) and, later, `BLERingTransport` (real
/// CoreBluetooth). Main-actor isolated: iteration 0 drives it entirely from the UI flow.
@MainActor
protocol RingTransport: AnyObject {
    func connect() async throws
    func disconnect()
    /// Sends a 16-byte command packet and returns the ring's response packet.
    func send(_ command: Data) async throws -> Data
    /// Sends a command and accumulates inbound packets until `isComplete` returns true,
    /// then returns all collected packets. Used for multi-packet history reads.
    /// `perPacketTimeout` is the maximum wait between consecutive inbound packets.
    func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool, perPacketTimeout: TimeInterval) async throws -> [Data]

    /// Whether the connected ring exposes the Big-Data V2 GATT service. False when the ring
    /// lacks the service or no connection has been established.
    var supportsBigData: Bool { get }

    /// Writes raw bytes to the Big-Data V2 write characteristic and accumulates V2 notify
    /// packets until `isComplete` returns true, then returns all collected packets.
    func sendBigData(_ data: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data]

    /// Writes a command WITHOUT awaiting a response — used to fire live-HR keepalives while a
    /// paged read is collecting heart-rate frames. Default no-op (mock/stub ignore it).
    func fireAndForget(_ command: Data)

    /// Writes each command (spaced `gap` apart) and collects EVERY V1 notify frame whose
    /// opcode == `opcode` into one buffer. Used for the HR history "global collector": the ring
    /// delivers a day's 24 packets slowly and out of step with per-read windows, so we fire all
    /// day queries and gather every 0x15 frame, then split by header and parse per day. The
    /// window is DYNAMIC — it keeps waiting while new frames arrive, stops after `quietPeriod`
    /// seconds of silence, and caps at `maxWindow`. Default returns [].
    func gather(commands: [Data], opcode: UInt8, gap: TimeInterval,
                quietPeriod: TimeInterval, maxWindow: TimeInterval) async -> [Data]

    /// Repeatedly writes `command` every `interval` seconds until `stopKeepalive()` — the ring
    /// needs a periodic CONTINUE to keep streaming live HR. Default no-ops (mock/stub).
    func startKeepalive(_ command: Data, interval: TimeInterval)
    func stopKeepalive()

    // MARK: Ring binding (remember my ring)

    /// When non-nil, `connect()` must only accept a peripheral with this identifier.
    /// `RingManager` sets this before calling `connect()` once a ring has been bound.
    /// Default implementation is a no-op (mock/stub transports ignore binding).
    var boundRingID: UUID? { get set }

    /// The identifier of the peripheral that connected successfully most recently.
    /// `RingManager` reads this after a successful connect to persist a new binding.
    /// Default returns nil (mock/stub transports never produce a real peripheral id).
    var connectedRingID: UUID? { get }

    /// The advertised name of the most recently connected ring.
    /// Default returns nil.
    var connectedRingName: String? { get }
}

// Default no-op conformances so existing MockRingTransport / StubTransport compile unchanged.
extension RingTransport {
    func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data] {
        try await send(command, isComplete: isComplete, perPacketTimeout: 8)
    }

    var boundRingID: UUID? {
        get { nil }
        // swiftlint:disable:next unused_setter_value
        set {}
    }
    var connectedRingID: UUID? { nil }
    var connectedRingName: String? { nil }
    func gather(commands: [Data], opcode: UInt8, gap: TimeInterval,
                quietPeriod: TimeInterval, maxWindow: TimeInterval) async -> [Data] { [] }
    func fireAndForget(_ command: Data) {}
    func startKeepalive(_ command: Data, interval: TimeInterval) {}
    func stopKeepalive() {}
}
