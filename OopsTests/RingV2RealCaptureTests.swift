import Foundation
import Testing
@testable import Oops

/// Replays REAL Big-Data V2 responses captured from the official QRing app (PacketLogger), so we
/// can verify the SpO2/sleep/temperature parsers deterministically (these persisted 0 on-device).
struct RingV2RealCaptureTests {
    static func hex(_ s: String) -> Data {
        var d = Data(); var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2)
            d.append(UInt8(s[i..<j], radix: 16)!); i = j
        }
        return d
    }

    static var cal: Calendar { Calendar.current }
    static var today: Date { cal.date(from: DateComponents(year: 2026, month: 6, day: 19))! }

    // Real BC2A (SpO2) full-week response — header + day record with 0x61 (97%) values.
    static let spo2Hex =
        "bc2a62006b060100000000000000000000000000000000000000000000000000000000000000000000000000000000000000006161616100606060606363606060606060616100000000616100000000616100000000000000000000000000000000000000000000"

    // Real BC27 (sleep) response — one night's hypnogram (stage,duration pairs).
    static let sleepHex =
        "bc272700a53f0100241b00ba01021f040e030c0411032302230313040f031b0414023504160319023404120214"

    @Test func parsesRealSpO2() {
        let samples = RingBigData.parseSpO2([Self.hex(Self.spo2Hex)], today: Self.today, calendar: Self.cal)
        #expect(!samples.isEmpty, "SpO2 parser returned nothing for a real response")
        let pcts = samples.map { Int($0.value) }
        #expect(pcts.allSatisfy { $0 >= 70 && $0 <= 100 }, "implausible SpO2 in \(pcts.prefix(10))")
    }

    // Real multi-day BC25 (temperature) response — 3 day-records with 0xA6/0xA7 raw values.
    static let tempHex = [
        "bc253200b3ae011e00000000000000000000000000000000000000000000000000000000000000000000009f9e0000a50000000000a7a7a6",
        "bc253200b9fa001ea6a7a7a7a5a6a6a6a6a6a6a7a6a5a7000000a6a60000a500000000000000000000000000000000000000000000000000",
        "bc2532002d93001ea6a7a7a7a5a6a6a6a6a6a6a7a6a5a7000000a6a60000a50000a700000000000000000000000000000000000000000000"
    ]

    @Test func parsesRealMultiDayTemperature() {
        let packets = Self.tempHex.map(Self.hex)
        let readings = RingBigData.parseTemperature(packets, today: Self.today, calendar: Self.cal)
        #expect(!readings.isEmpty, "Temperature parser returned nothing for a real multi-day response")
        let c = readings.map(\.celsius)
        #expect(c.allSatisfy { $0 >= 28 && $0 <= 43 }, "implausible temperature in \(c.prefix(10))")
    }

    @Test func parsesRealSleep() {
        let intervals = RingBigData.parseSleep([Self.hex(Self.sleepHex)], today: Self.today, calendar: Self.cal)
        #expect(!intervals.isEmpty, "Sleep parser returned nothing for a real response")
        #expect(intervals.allSatisfy { $0.end > $0.start })
    }
}
