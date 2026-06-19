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

    // MARK: - V2 Big Data (0x27) — QRing/oudmon SDK protocol

    /// sleepRequest() must produce exactly BC 27 02 00 C1 E0 01 01 (matches the official QRing app)
    @Test func sleepRequestBytes() {
        let req = Array(RingBigData.sleepRequest())
        #expect(req == [0xBC, 0x27, 0x02, 0x00, 0xC1, 0xE0, 0x01, 0x01])
    }

    @Test func sleepCompleteReturnsFalseOnEmpty() {
        #expect(!RingBigData.sleepComplete([]))
    }

    @Test func sleepCompleteReturnsTrueWhenFullPayloadPresent() {
        // 6-byte header + payloadLen bytes
        let payloadLen = 11
        var bytes = [UInt8](repeating: 0, count: 6 + payloadLen)
        bytes[0] = 0xBC; bytes[1] = 0x27
        bytes[2] = UInt8(payloadLen & 0xFF); bytes[3] = UInt8(payloadLen >> 8)
        #expect(RingBigData.sleepComplete([Data(bytes)]))
    }

    @Test func sleepCompleteReturnsTrueForZeroLen() {
        let bytes: [UInt8] = [0xBC, 0x27, 0x00, 0x00, 0x00, 0x00]
        #expect(RingBigData.sleepComplete([Data(bytes)]))
    }

    @Test func sleepCompleteReturnsFalseForPartialPayload() {
        // 6-byte header declaring 11 bytes payload, but no payload bytes follow
        let bytes: [UInt8] = [0xBC, 0x27, 11, 0x00, 0x00, 0x00]
        #expect(!RingBigData.sleepComplete([Data(bytes)]))
    }

    /// Build a minimal but spec-correct V2 response and assert parse correctness.
    /// Payload: indicator=1, dayBlock: dayOffset=0, blockLenField=8,
    /// discard=0,0, endMinutes=480 (8am), light 30min, deep 20min.
    /// total=50min → startTime=7:10am; last.end == 8am.
    @Test func parseSleepV2YieldsContiguousIntervals() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        let dayBlock: [UInt8] = [
            0x00,         // dayOffset=0
            0x08,         // blockLenField=8 (blockLen=10)
            0x00, 0x00,   // discarded
            0xE0, 0x01,   // endMinutes=480 LE
            0x02, 30,     // light, 30 min
            0x03, 20      // deep, 20 min
        ]
        let payload: [UInt8] = [0x01] + dayBlock
        let response = RingBigData.bigDataRequest(action: 0x27, payload: payload)
        let intervals = RingBigData.parseSleep([response], today: today, calendar: Self.utc)
        #expect(intervals.count == 2)
        #expect(intervals[0].stage == .light)
        #expect(intervals[1].stage == .deep)
        #expect(intervals[1].start == intervals[0].end)
        #expect(intervals[0].end.timeIntervalSince(intervals[0].start) == 30 * 60)
        // last.end == 8am (480 min past midnight)
        let eightAm = today.addingTimeInterval(480 * 60)
        #expect(intervals[1].end == eightAm)
    }

    @Test func parseSleepV2MapsAllStageCodes() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        // 4 pairs × 2 = 8 pair bytes; blockLen=14, blockLenField=12; endMinutes=120
        let dayBlock: [UInt8] = [
            0x00, 0x0C, 0x00, 0x00, 0x78, 0x00,   // dayOffset=0, blockLenField=12, discard, endMin=120
            0x02, 10,   // light
            0x03, 10,   // deep
            0x04, 10,   // rem
            0x05, 10    // awake
        ]
        let payload: [UInt8] = [0x01] + dayBlock
        let response = RingBigData.bigDataRequest(action: 0x27, payload: payload)
        let intervals = RingBigData.parseSleep([response], today: today, calendar: Self.utc)
        #expect(intervals.count == 4)
        #expect(intervals[0].stage == .light)
        #expect(intervals[1].stage == .deep)
        #expect(intervals[2].stage == .rem)
        #expect(intervals[3].stage == .awake)
    }

    @Test func parseSleepV2SkipsUnknownStageCodes() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        // 3 pairs × 2 = 6 pair bytes; blockLen=12, blockLenField=10; endMinutes=60
        let dayBlock: [UInt8] = [
            0x00, 0x0A, 0x00, 0x00, 0x3C, 0x00,   // dayOffset=0, blockLenField=10, discard, endMin=60
            0xFF, 10,   // unknown → skip but advance cursor
            0x02, 30,   // light 30 min
            0x03, 20    // deep 20 min
        ]
        let payload: [UInt8] = [0x01] + dayBlock
        let response = RingBigData.bigDataRequest(action: 0x27, payload: payload)
        let intervals = RingBigData.parseSleep([response], today: today, calendar: Self.utc)
        #expect(intervals.count == 2)
        #expect(intervals[0].stage == .light)
        // total=60min, endMinutes=60→1am; startTime=midnight; unknown 10min → light starts at 10min past midnight
        #expect(intervals[0].start == today.addingTimeInterval(10 * 60))
    }

    @Test func parseSleepV2ReturnsEmptyWhenIndicatorIsZero() {
        let today = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        let payload: [UInt8] = [0x00]   // indicator=0 → no sleep data
        let response = RingBigData.bigDataRequest(action: 0x27, payload: payload)
        let intervals = RingBigData.parseSleep([response], today: today, calendar: Self.utc)
        #expect(intervals.isEmpty)
    }
}
