import Foundation
import Testing
@testable import Oops

struct RingSleepHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func commandUses0x44WithUTCMidnight() {
        let day = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        let p = Array(RingProtocol.sleepHistoryCommand(day: day, calendar: Self.utc))
        #expect(p[0] == 0x44)
        #expect(Array(p[1...4]) == RingProtocol.uint32LE(UInt32(day.timeIntervalSince1970)))
    }

    @Test func parsesContiguousStageIntervals() {
        let dayStart = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        var header = [UInt8](repeating: 0, count: 16); header[0] = 0x44; header[1] = 0; header[2] = 1
        var data = [UInt8](repeating: 0, count: 16); data[0] = 0x44; data[1] = 1
        data[2] = 1; data[3] = 30   // light, 30 min
        data[4] = 2; data[5] = 20   // deep, 20 min
        let intervals = RingProtocol.parseSleep([Data(header), Data(data)], dayStart: dayStart)
        #expect(intervals.count == 2)
        #expect(intervals[0].stage == .light)
        #expect(intervals[1].stage == .deep)
        #expect(intervals[1].start == intervals[0].end)
        #expect(intervals[0].end.timeIntervalSince(intervals[0].start) == 30 * 60)
    }
}
