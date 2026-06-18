import Foundation
import Testing
@testable import Oops

struct RingSpO2Tests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func liveStartRequestsType3() {
        let p = Array(RingProtocol.liveSpO2StartCommand())
        #expect(p[0] == 0x69 && p[1] == 0x03 && p[2] == 0x01)
    }

    @Test func parsesLivePercent() {
        var b = [UInt8](repeating: 0, count: 16); b[0] = 0x69; b[1] = 3; b[2] = 0; b[3] = 97
        #expect(RingProtocol.parseLiveSpO2(Data(b)) == 97)
    }

    @Test func historyCommandUses0x2C() {
        let day = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        #expect(Array(RingProtocol.spo2HistoryCommand(day: day, calendar: Self.utc))[0] == 0x2C)
    }

    @Test func parsesHistoryValues() {
        let dayStart = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        var header = [UInt8](repeating: 0, count: 16); header[0] = 0x2C; header[1] = 0; header[2] = 1; header[3] = 60
        var data = [UInt8](repeating: 0, count: 16); data[0] = 0x2C; data[1] = 1; data[2] = 96; data[3] = 0; data[4] = 98
        let samples = RingProtocol.parseSpO2History([Data(header), Data(data)], dayStart: dayStart)
        #expect(samples.map(\.value) == [96, 98])
    }
}
