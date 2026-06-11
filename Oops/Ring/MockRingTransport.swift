import Foundation

/// A simulated ring. Responds to command packets with realistic responses built via
/// `RingProtocol`, so the whole app runs end-to-end before the hardware arrives.
@MainActor
final class MockRingTransport: RingTransport {
    var batteryLevel: Int
    var isCharging: Bool

    init(batteryLevel: Int = 72, isCharging: Bool = false) {
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
    }

    func connect() async throws {}
    func disconnect() {}

    func send(_ command: Data) async throws -> Data {
        switch command.first {
        case 0x03:
            return RingProtocol.makePacket(
                command: 0x03,
                payload: [UInt8(batteryLevel), isCharging ? 1 : 0]
            )
        default:
            throw RingError.unsupportedCommand
        }
    }
}
