import Foundation
import Testing
@testable import Oops

struct RingLiveHRTests {
    @Test func startCommandRequestsHeartRateType() {
        let p = Array(RingProtocol.liveHRStartCommand())
        #expect(p[0] == 0x69)
        #expect(p[1] == 0x01) // reading type 1 = HR
        #expect(p[2] == 0x01) // action = start
    }

    @Test func stopCommandUses0x6A() {
        #expect(Array(RingProtocol.liveHRStopCommand())[0] == 0x6A)
    }

    @Test func parsesBPMWhenNoError() {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = 0x69; bytes[1] = 0x01; bytes[2] = 0x00; bytes[3] = 65
        #expect(RingProtocol.parseLiveHR(Data(bytes)) == 65)
    }

    @Test func returnsNilOnErrorByte() {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = 0x69; bytes[1] = 0x01; bytes[2] = 0x01; bytes[3] = 65
        #expect(RingProtocol.parseLiveHR(Data(bytes)) == nil)
    }
}
