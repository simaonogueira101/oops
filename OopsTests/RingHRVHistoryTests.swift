import Foundation
import Testing
@testable import Oops

struct RingHRVHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func commandUses0x39() {
        let day = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        #expect(Array(RingProtocol.hrvHistoryCommand(day: day, calendar: Self.utc))[0] == 0x39)
    }

    @Test func parsesNonZeroHRVAtInterval() {
        let dayStart = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        var header = [UInt8](repeating: 0, count: 16); header[0] = 0x39; header[1] = 0; header[2] = 1; header[3] = 30
        var data = [UInt8](repeating: 0, count: 16); data[0] = 0x39; data[1] = 1
        data[2] = 40; data[3] = 0; data[4] = 55
        let samples = RingProtocol.parseHRV([Data(header), Data(data)], dayStart: dayStart)
        #expect(samples.count == 2)
        #expect(samples[0].value == 40)
        #expect(samples[1].value == 55)
        #expect(samples[1].date.timeIntervalSince(samples[0].date) == 60 * 60) // two 30-min slots
    }

    @Test func parsesEmptyResponseGracefully() {
        let dayStart = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        // 0xFF in data bytes (no reading) → empty result
        var header = [UInt8](repeating: 0, count: 16); header[0] = 0x39; header[1] = 0; header[2] = 1; header[3] = 30
        var data = [UInt8](repeating: 0, count: 16); data[0] = 0x39; data[1] = 1
        // all data bytes remain 0x00 (treated as no reading)
        let samples = RingProtocol.parseHRV([Data(header), Data(data)], dayStart: dayStart)
        #expect(samples.isEmpty)
    }

    @Test func enableHRVCommandUses0x38() {
        let cmd = RingProtocol.enableHRVCommand()
        #expect(Array(cmd)[0] == 0x38)
        #expect(Array(cmd)[1] == 0x02)
        #expect(Array(cmd)[2] == 0x01)
    }
}
