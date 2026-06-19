import Foundation
import Testing
@testable import Oops

/// Replays a REAL `0x15` heart-rate-history response for one populated day, captured from the
/// official QRing app over PacketLogger. Lets us verify the parser deterministically in the
/// Simulator (no ring) instead of against the flaky live BLE connection.
struct RingHRRealCaptureTests {
    /// Header (subtype 0, count 0x18=24, 5-min interval) + 23 data pages. Pages 1–12 carry real
    /// BPM values (0x37=55, 0x53=83, …); pages 13–23 are end-of-day zeros.
    static let dayPacketsHex = [
        "15001805000000000000000000000032",
        "15018086346a375338345f3433605026",
        "150235353233323b4a353535343a39e3",
        "1503333332343c35343537344b3e31e3",
        "1504333d314236623c3b375e56313057",
        "1505373831303230323131593f2f38df",
        "150641573e503c3b44313246413b5e7f",
        "1507583132315130315848315a46325d",
        "150837410000000000000000000050e5",
        "1509000000000061504c5650565264cd",
        "150a56584c51000000004e3a000000f2",
        "150b0000003e55534b560000000000a7",
        "150c0000000000000058554047000055",
        "150d0000000000000000000000000022",
        "150e0000000000000000000000000023",
        "150f0000000000000000000000000024",
        "15100000000000000000000000000025",
        "15110000000000000000000000000026",
        "15120000000000000000000000000027",
        "15130000000000000000000000000028",
        "15140000000000000000000000000029",
        "1515000000000000000000000000002a",
        "1516000000000000000000000000002b",
        "1517000000000000000000000000002c"
    ]

    static func hex(_ s: String) -> Data {
        var d = Data(); var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2)
            d.append(UInt8(s[i..<j], radix: 16)!); i = j
        }
        return d
    }

    @Test func completesOnRealDay() {
        let packets = Self.dayPacketsHex.map(Self.hex)
        #expect(RingProtocol.heartRateHistoryComplete(packets))
    }

    @Test func parsesRealHRDayIntoPlausibleBPM() {
        let packets = Self.dayPacketsHex.map(Self.hex)
        let samples = RingProtocol.parseHeartRateHistory(packets)
        let bpms = samples.map { Int($0.value) }
        #expect(samples.count > 30, "expected dozens of BPM samples, got \(samples.count)")
        #expect(bpms.allSatisfy { $0 >= 30 && $0 <= 220 }, "implausible BPM in \(bpms.prefix(10))")
        // First sample should be the first non-zero value (0x37 = 55).
        #expect(bpms.first == 55)
    }
}
