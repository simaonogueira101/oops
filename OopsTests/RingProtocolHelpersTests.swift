import Foundation
import Testing
@testable import Oops

struct RingProtocolHelpersTests {
    @Test func uint32LEIsLittleEndianFourBytes() {
        #expect(RingProtocol.uint32LE(0x01020304) == [0x04, 0x03, 0x02, 0x01])
    }

    @Test func bcdEncodesDecimalDigits() {
        #expect(RingProtocol.bcd(26) == 0x26)
        #expect(RingProtocol.bcd(9) == 0x09)
    }

    @Test func utcMidnightUnixIsStartOfDayUTC() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 6, day: 18, hour: 13))!
        let midnight = cal.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        #expect(RingProtocol.utcMidnightUnix(for: date, calendar: cal) == UInt32(midnight.timeIntervalSince1970))
    }
}
