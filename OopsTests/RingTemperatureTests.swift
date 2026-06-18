import Foundation
import Testing
@testable import Oops

struct RingTemperatureTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func enableCommandIsV1ChecksummedPacket() {
        let p = Array(RingProtocol.enableAllDayTemperatureCommand())
        #expect(p.count == 16)
        #expect(p[0] == 0x3A && p[1] == 0x03 && p[2] == 0x02 && p[3] == 0x01)
        #expect(p[15] == UInt8(p[0..<15].reduce(0) { $0 + Int($1) } % 255)) // checksum present
    }

    @Test func temperatureRequestIsRawSevenBytes() {
        #expect(Array(RingBigData.temperatureRequest()) == [0xBC, 0x25, 0x01, 0x00, 0x3E, 0x81, 0x02])
    }

    @Test func completeWhenDeclaredLengthReached() {
        // header [BC 25 len_lo len_hi] + payload of `len` bytes
        let payload = [UInt8](repeating: 0, count: 8)
        let len = payload.count
        var full = [0xBC, 0x25, UInt8(len & 0xFF), UInt8(len >> 8)]; full += payload
        #expect(RingBigData.temperatureComplete([Data(full)]))
        #expect(!RingBigData.temperatureComplete([Data(full.prefix(6))]))
    }

    @Test func parsesUnsignedScalingAndHalfHourSlots() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18, hour: 10))!
        // payload (from index 4): [pad0, pad1] then block [days_ago=0][0x1E][48 slots]
        var block: [UInt8] = [0x00, 0x00, 0x00, 0x1E]
        var slots = [UInt8](repeating: 0, count: 48)
        slots[0] = 165   // (165/10)+20 = 36.5°C
        slots[2] = 200   // (200 & 0xFF)/10 + 20 = 40.0°C — unsigned read matters (>127)
        block += slots
        let len = block.count
        var full: [UInt8] = [0xBC, 0x25, UInt8(len & 0xFF), UInt8(len >> 8)]; full += block
        let readings = RingBigData.parseTemperature([Data(full)], today: today, calendar: Self.utc)
        #expect(readings.count == 2)
        #expect(abs(readings[0].celsius - 36.5) < 0.001)
        #expect(abs(readings[1].celsius - 40.0) < 0.001)
        // slot 0 is at start-of-day; slot 2 is 60 min later
        #expect(readings[1].date.timeIntervalSince(readings[0].date) == 2 * 1800)
        #expect(readings[0].date == Self.utc.startOfDay(for: today))
    }
}
