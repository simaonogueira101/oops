import Foundation
import Testing
@testable import Oops

struct RingHeartRateHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func commandEncodesUTCMidnightLE() {
        let day = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        let p = Array(RingProtocol.heartRateHistoryCommand(day: day, calendar: Self.utc))
        #expect(p[0] == 0x15)
        let ts = UInt32(day.timeIntervalSince1970)
        #expect(Array(p[1...4]) == RingProtocol.uint32LE(ts))
    }

    @Test func completeWhenAllDataPacketsReceived() {
        // The header count INCLUDES the header packet (QRing: count 0x18=24 → 23 data pages),
        // so completion fires at count-1 data packets. Here count 3 = header + 2 data pages.
        let header = Self.packet(sub: 0, payload: [3, 5])
        let d1 = Self.packet(sub: 1, payload: [])
        #expect(!RingProtocol.heartRateHistoryComplete([header]))
        #expect(!RingProtocol.heartRateHistoryComplete([header, d1]))
        let d2 = Self.packet(sub: 2, payload: [])
        #expect(RingProtocol.heartRateHistoryComplete([header, d1, d2]))
    }

    @Test func completeOnErrorPacket() {
        #expect(RingProtocol.heartRateHistoryComplete([Self.packet(sub: 255, payload: [])]))
    }

    @Test func parsesValuesWithFiveMinuteCadence() {
        let start = UInt32(Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!.timeIntervalSince1970)
        let header = Self.packet(sub: 0, payload: [1, 5])
        var first = [UInt8](repeating: 0, count: 16)
        first[0] = 0x15; first[1] = 1
        let ts = RingProtocol.uint32LE(start)
        first[2] = ts[0]; first[3] = ts[1]; first[4] = ts[2]; first[5] = ts[3]
        first[6] = 60; first[7] = 0; first[8] = 62   // 3 readings, middle is "no reading"
        first[15] = 99                                // non-zero checksum; must not be read as value
        let samples = RingProtocol.parseHeartRateHistory([header, Data(first)])
        #expect(samples.count == 2)                  // zeros dropped
        #expect(samples[0].value == 60)
        #expect(samples[1].value == 62)
        #expect(samples[1].date.timeIntervalSince(samples[0].date) == 10 * 60) // two 5-min slots apart
    }

    static func packet(sub: UInt8, payload: [UInt8]) -> Data {
        var b = [UInt8](repeating: 0, count: 16)
        b[0] = 0x15; b[1] = sub
        for (i, v) in payload.prefix(2).enumerated() { b[2 + i] = v }
        return Data(b)
    }
}
