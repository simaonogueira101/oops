import Foundation
import Testing
@testable import Oops

struct RingTimeCommandTests {
    @Test func setTimeIsBCDInUTC() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 6, day: 18,
                                                 hour: 9, minute: 7, second: 5))!
        let packet = Array(RingProtocol.setTimeCommand(date: date, calendar: cal))

        #expect(packet[0] == 0x01)
        #expect(packet[1] == 0x26) // year 26 BCD
        #expect(packet[2] == 0x06) // month
        #expect(packet[3] == 0x18) // day 18 BCD
        #expect(packet[4] == 0x09) // hour
        #expect(packet[5] == 0x07) // minute
        #expect(packet[6] == 0x05) // second
        #expect(packet[7] == 0x01) // language = English
    }
}
