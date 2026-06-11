import Foundation

/// Errors surfaced by a ring transport.
enum RingError: Error, Equatable {
    case unsupportedCommand
    case notConnected
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
}
