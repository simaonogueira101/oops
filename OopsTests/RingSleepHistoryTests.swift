import Foundation
import Testing
@testable import Oops

struct RingSleepHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    // MARK: - V1 sleep history (kept for protocol regression coverage)

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

    // MARK: - V2 Big Data (0x27)

    @Test func sleepRequestBytes() {
        let req = Array(RingBigData.sleepRequest())
        #expect(req[0] == 0xBC)
        #expect(req[1] == 0x27)
        #expect(req[2] == 0x01)
        #expect(req[3] == 0x00)
    }

    @Test func sleepCompleteReturnsFalseOnEmpty() {
        #expect(!RingBigData.sleepComplete([]))
    }

    @Test func sleepCompleteReturnsTrueWhenFullPayloadPresent() {
        // payload = 2 filler + 1 daysAgo + 4 pairs × 2 = 11
        let len: UInt8 = 11
        var bytes = [UInt8](repeating: 0, count: 4 + Int(len))
        bytes[0] = 0xBC; bytes[1] = 0x27; bytes[2] = len; bytes[3] = 0
        #expect(RingBigData.sleepComplete([Data(bytes)]))
    }

    @Test func sleepCompleteReturnsTrueForZeroLen() {
        let bytes: [UInt8] = [0xBC, 0x27, 0x00, 0x00]
        #expect(RingBigData.sleepComplete([Data(bytes)]))
    }

    @Test func sleepCompleteReturnsFalseForPartialPayload() {
        let bytes: [UInt8] = [0xBC, 0x27, 11, 0x00]   // declare 11 bytes but supply none
        #expect(!RingBigData.sleepComplete([Data(bytes)]))
    }

    @Test func parseSleepV2YieldsContiguousIntervals() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        // daysAgo=0, light 30 min, deep 20 min → starts at today's midnight
        let len: UInt8 = 2 + 1 + 4   // 2 filler + 1 daysAgo + 2 pairs × 2
        let bytes: [UInt8] = [0xBC, 0x27, len, 0x00, 0x00, 0x00,   // header + 2 filler
                               0x00,                                   // daysAgo=0
                               0x02, 30,                               // light, 30 min
                               0x03, 20]                               // deep, 20 min
        let intervals = RingBigData.parseSleep([Data(bytes)], today: today, calendar: Self.utc)
        #expect(intervals.count == 2)
        #expect(intervals[0].stage == .light)
        #expect(intervals[1].stage == .deep)
        #expect(intervals[1].start == intervals[0].end)
        #expect(intervals[0].end.timeIntervalSince(intervals[0].start) == 30 * 60)
        #expect(intervals[0].start == today)
    }

    @Test func parseSleepV2MapsAllStageCodes() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        // 02=light 03=deep 04=rem 05=awake
        let len: UInt8 = 2 + 1 + 8
        let bytes: [UInt8] = [0xBC, 0x27, len, 0x00, 0x00, 0x00,
                               0x00,
                               0x02, 10,   // light
                               0x03, 10,   // deep
                               0x04, 10,   // rem
                               0x05, 10]   // awake
        let intervals = RingBigData.parseSleep([Data(bytes)], today: today, calendar: Self.utc)
        #expect(intervals.count == 4)
        #expect(intervals[0].stage == .light)
        #expect(intervals[1].stage == .deep)
        #expect(intervals[2].stage == .rem)
        #expect(intervals[3].stage == .awake)
    }

    @Test func parseSleepV2SkipsUnknownStageCodes() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        let len: UInt8 = 2 + 1 + 6
        let bytes: [UInt8] = [0xBC, 0x27, len, 0x00, 0x00, 0x00,
                               0x00,
                               0xFF, 10,   // unknown stage → skip but advance cursor
                               0x02, 30,   // light 30 min starts after the unknown 10 min
                               0x03, 20]   // deep 20 min
        let intervals = RingBigData.parseSleep([Data(bytes)], today: today, calendar: Self.utc)
        #expect(intervals.count == 2)
        #expect(intervals[0].stage == .light)
        // light starts 10 min after midnight (unknown stage advanced the cursor)
        #expect(intervals[0].start == today.addingTimeInterval(10 * 60))
    }
}
