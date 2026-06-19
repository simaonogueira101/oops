import Foundation
import Testing
@testable import Oops

struct RingStressHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func commandUses0x37WithDayIndex() {
        let p = Array(RingProtocol.stressHistoryCommand(dayOffset: 3))
        #expect(p[0] == 0x37)
        #expect(p[1] == 0x03) // day index payload
    }

    @Test func parsesNonZeroStressAtInterval() {
        let dayStart = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        var header = [UInt8](repeating: 0, count: 16); header[0] = 0x37; header[1] = 0; header[2] = 1; header[3] = 30
        var data = [UInt8](repeating: 0, count: 16); data[0] = 0x37; data[1] = 1
        data[2] = 40; data[3] = 0; data[4] = 55
        let samples = RingProtocol.parseStress([Data(header), Data(data)], dayStart: dayStart)
        #expect(samples.count == 2)
        #expect(samples[0].value == 40)
        #expect(samples[1].value == 55)
        #expect(samples[1].date.timeIntervalSince(samples[0].date) == 60 * 60) // two 30-min slots
    }
}
