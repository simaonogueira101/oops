import Foundation
import Testing
@testable import Oops

struct RingActivityHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func commandEncodesOffsetAndConstants() {
        let p = Array(RingProtocol.activityHistoryCommand(dayOffset: 0))
        #expect(p[0] == 0x43)
        #expect(Array(p[1...5]) == [0x00, 0x0f, 0x00, 0x5f, 0x01])
    }

    @Test func completeAfterDeclaredPackets() {
        let header = Self.header(flag: 0x01, count: 1)
        #expect(!RingProtocol.activityHistoryComplete([header]))
        #expect(RingProtocol.activityHistoryComplete([header, Self.dataPacket(steps: 100, cal: 5, dist: 70, idx: 4)]))
    }

    @Test func parsesStepsCaloriesDistanceAndTime() {
        let header = Self.header(flag: 0x01, count: 1)             // not ×10
        let packet = Self.dataPacket(steps: 250, cal: 12, dist: 180, idx: 5) // 01:15
        let points = RingProtocol.parseActivityHistory([header, packet], calendar: Self.utc)
        #expect(points.count == 1)
        #expect(points[0].steps == 250)
        #expect(points[0].calories == 12)
        #expect(points[0].distanceMeters == 180)
        let comps = Self.utc.dateComponents([.hour, .minute], from: points[0].date)
        #expect(comps.hour == 1 && comps.minute == 15)
    }

    @Test func caloriesScaledWhenHeaderIs240() {
        let header = Self.header(flag: 0xF0, count: 1)
        let packet = Self.dataPacket(steps: 0, cal: 12, dist: 0, idx: 0)
        #expect(RingProtocol.parseActivityHistory([header, packet], calendar: Self.utc)[0].calories == 120)
    }

    static func header(flag: UInt8, count: UInt8) -> Data {
        var b = [UInt8](repeating: 0, count: 16); b[0] = 0x43; b[1] = flag; b[2] = count; return Data(b)
    }
    static func dataPacket(steps: Int, cal: Int, dist: Int, idx: UInt8) -> Data {
        var b = [UInt8](repeating: 0, count: 16); b[0] = 0x43
        b[1] = RingProtocol.bcd(26); b[2] = 0x06; b[3] = RingProtocol.bcd(18); b[4] = idx  // date BCD + time index
        b[7] = UInt8(cal & 0xFF); b[8] = UInt8(cal >> 8)
        b[9] = UInt8(steps & 0xFF); b[10] = UInt8(steps >> 8)
        b[11] = UInt8(dist & 0xFF); b[12] = UInt8(dist >> 8)
        return Data(b)
    }
}
