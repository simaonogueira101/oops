import Foundation
import Testing
@testable import Oops

struct RingSpO2Tests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    // MARK: - V1 live / history (kept for protocol regression coverage)

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

    // MARK: - V2 Big Data (0x2A)

    @Test func spo2RequestBytes() {
        let req = Array(RingBigData.spo2Request())
        #expect(req[0] == 0xBC)
        #expect(req[1] == 0x2A)
        #expect(req[2] == 0x01)
        #expect(req[3] == 0x00)
    }

    @Test func spo2CompleteReturnsFalseOnEmpty() {
        #expect(!RingBigData.spo2Complete([]))
    }

    @Test func spo2CompleteReturnsTrueWhenFullPayloadPresent() {
        // payload=51: 2 filler + 1 daysAgo + 48 pairs
        let len: UInt8 = 51
        var bytes = [UInt8](repeating: 0, count: 4 + Int(len))
        bytes[0] = 0xBC; bytes[1] = 0x2A; bytes[2] = len; bytes[3] = 0
        #expect(RingBigData.spo2Complete([Data(bytes)]))
    }

    @Test func spo2CompleteReturnsTrueForZeroLen() {
        let bytes: [UInt8] = [0xBC, 0x2A, 0x00, 0x00]
        #expect(RingBigData.spo2Complete([Data(bytes)]))
    }

    @Test func spo2CompleteReturnsFalseForPartialPayload() {
        // declare len=51 but only supply 4 header bytes → not yet complete
        let bytes: [UInt8] = [0xBC, 0x2A, 51, 0x00]
        #expect(!RingBigData.spo2Complete([Data(bytes)]))
    }

    @Test func parseSpO2YieldsHourlyAverages() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        // Single-day block: daysAgo=0, hour 0 → (94, 98), rest zeros
        var pairs = [UInt8](repeating: 0, count: 48)
        pairs[0] = 94; pairs[1] = 98   // hour 0: avg = (94+98)/2 = 96
        let len: UInt8 = 51            // 2 filler + 1 daysAgo + 48 pairs
        var bytes: [UInt8] = [0xBC, 0x2A, len, 0x00, 0x00, 0x00, 0x00]
        bytes.append(contentsOf: pairs)
        let samples = RingBigData.parseSpO2([Data(bytes)], today: today, calendar: Self.utc)
        #expect(samples.count == 1)
        #expect(samples[0].value == 96)
        #expect(samples[0].date == today)   // hour 0 of that day
    }

    @Test func parseSpO2SkipsZeroPairs() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        var bytes: [UInt8] = [0xBC, 0x2A, 51, 0x00, 0x00, 0x00, 0x00]
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 48))
        let samples = RingBigData.parseSpO2([Data(bytes)], today: today, calendar: Self.utc)
        #expect(samples.isEmpty)
    }

    @Test func enableAllDaySpO2CommandUses0x2C() {
        let cmd = Array(RingProtocol.enableAllDaySpO2Command())
        #expect(cmd[0] == 0x2C)
        #expect(cmd[1] == 0x02)
        #expect(cmd[2] == 0x01)
    }
}
