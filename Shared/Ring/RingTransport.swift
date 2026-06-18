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
protocol RingTransport {
    func connect() async throws
    func disconnect()
    /// Sends a 16-byte command packet and returns the ring's response packet.
    func send(_ command: Data) async throws -> Data
    /// Sends a command and accumulates inbound packets until `isComplete` returns true,
    /// then returns all collected packets. Used for multi-packet history reads.
    func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data]
}
