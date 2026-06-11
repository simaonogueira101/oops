import Foundation
import Testing
@testable import Oops

struct RingProtocolTests {
    @Test func packetIs16BytesWithCommandAndChecksum() {
        let packet = RingProtocol.makePacket(command: 0x03)

        #expect(packet.count == 16)
        #expect(packet[0] == 0x03)
        #expect(Array(packet[1..<15]).allSatisfy { $0 == 0 })
        // checksum = sum(bytes[0..<15]) % 255 = 0x03
        #expect(packet[15] == 0x03)
    }

    @Test func batteryCommandUsesCommandByte0x03() {
        let packet = RingProtocol.batteryCommand()

        #expect(packet.count == 16)
        #expect(packet[0] == 0x03)
    }

    @Test func parsesBatteryLevelAndChargingFromResponse() {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = 0x03   // echoed command
        bytes[1] = 72     // level %
        bytes[2] = 1      // charging

        let status = RingProtocol.parseBattery(Data(bytes))

        #expect(status == BatteryStatus(level: 72, isCharging: true))
    }

    @Test func parseBatteryReturnsNilForTooShortData() {
        #expect(RingProtocol.parseBattery(Data([0x03, 50])) == nil)
    }
}
