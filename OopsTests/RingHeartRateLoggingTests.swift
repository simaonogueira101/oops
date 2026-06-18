import Foundation
import Testing
@testable import Oops

struct RingHeartRateLoggingTests {
    @Test func enableCommandIs0x16WithSetEnabledInterval() {
        let p = Array(RingProtocol.enableHeartRateLoggingCommand(intervalMinutes: 5))
        #expect(p.count == 16)
        #expect(p[0] == 0x16 && p[1] == 0x02 && p[2] == 0x01 && p[3] == 5)
        #expect(p[15] == UInt8(p[0..<15].reduce(0) { $0 + Int($1) } % 255))
    }
}
