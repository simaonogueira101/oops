import Foundation
import Testing
@testable import Oops

/// Regression fixtures built from REAL packets captured off a worn Colmi R09 (2026-06-18).
/// These lock the protocol parsers against actual hardware output so they can't silently break.
struct RingRealDataRegressionTests {
    static func p(_ s: String) -> Data {
        Data(s.split(separator: " ").map { UInt8($0, radix: 16)! })
    }
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }

    @Test func liveHR_realFrame_decodesTo76() {
        #expect(RingProtocol.parseLiveHR(Self.p("69 01 00 4C 00 00 C3 02 00 00 00 00 00 00 00 7B")) == 76)
    }

    @Test func hrHistory_realPackets_yieldRealBPM() {
        let pkts = [
            Self.p("15 00 18 05 00 00 00 00 00 00 00 00 00 00 00 32"),
            Self.p("15 01 00 35 33 6A 00 00 00 00 00 00 00 00 00 E8"),
            Self.p("15 11 00 00 00 00 49 00 00 00 00 00 00 00 00 6F"),
            Self.p("15 12 00 45 6D 00 00 00 00 00 00 00 00 00 00 D9"),
            Self.p("15 13 00 00 00 46 5F 64 4F 00 00 00 00 00 00 80"),
            Self.p("15 16 52 4B 60 54 6C 00 00 00 00 00 00 00 00 E8"),
        ]
        let values = Set(RingProtocol.parseHeartRateHistory(pkts).map { Int($0.value) })
        #expect(values.contains(73))    // 0x49
        #expect(values.contains(69))    // 0x45
        #expect(values.contains(109))   // 0x6D
        #expect(values.contains(108))   // 0x6C
        #expect(values.contains(100))   // 0x64
    }

    @Test func steps_realPackets_yield180And42() {
        let pkts = [
            Self.p("43 F0 02 01 00 00 00 00 00 00 00 00 00 00 00 36"),
            Self.p("43 26 06 18 44 00 02 E0 01 B4 00 6C 00 00 00 CE"),
            Self.p("43 26 06 18 4C 01 02 64 00 2A 00 16 00 00 00 7A"),
        ]
        let steps = Set(RingProtocol.parseActivityHistory(pkts, calendar: Self.utc).map(\.steps))
        #expect(steps.contains(180))   // 0x00B4
        #expect(steps.contains(42))    // 0x002A
    }

    @Test func stress_realPacket_yields36() {
        let pkts = [
            Self.p("37 00 05 1E 00 00 00 00 00 00 00 00 00 00 00 5A"),
            Self.p("37 04 00 00 00 00 00 00 00 24 00 00 00 00 00 5F"),
        ]
        let values = Set(RingProtocol.parseStress(pkts, dayStart: Self.utc.startOfDay(for: .now)).map { Int($0.value) })
        #expect(values.contains(36))   // 0x24
    }

    @Test func spo2V2_realResponse_decodesTo97() {
        let resp = Self.p("BC 2A 31 00 71 1D 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 61 61 00 00")
        let samples = RingBigData.parseSpO2([resp], today: Date(timeIntervalSince1970: 1_750_000_000), calendar: Self.utc)
        #expect(samples.map { Int($0.value) }.contains(97))   // (97+97)/2
    }

    @Test func tempV2_realResponse_decodesSkinTemps() {
        let resp = Self.p("BC 25 32 00 A5 39 00 1E 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 9F 9E 00 00 A5 00 00 00 00 00 A7 00 00")
        let readings = RingBigData.parseTemperature([resp], today: Date(timeIntervalSince1970: 1_750_000_000), calendar: Self.utc)
        let celsius = Set(readings.map { (($0.celsius * 10).rounded() / 10) })
        #expect(celsius.contains(35.9))   // 0x9F = 159
        #expect(celsius.contains(36.7))   // 0xA7 = 167
    }
}
