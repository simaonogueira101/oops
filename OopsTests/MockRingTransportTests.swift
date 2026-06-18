import Foundation
import Testing
@testable import Oops

@MainActor
struct MockRingTransportTests {
    @Test func pagedSendCollectsUntilComplete() async throws {
        let mock = MockRingTransport()
        try await mock.connect()
        let cmd = RingProtocol.heartRateHistoryCommand(day: .init(timeIntervalSince1970: 1_700_000_000), calendar: .current)
        let packets = try await mock.send(cmd, isComplete: RingProtocol.heartRateHistoryComplete)
        #expect(packets.count >= 2)
        #expect(packets.first?.first == 0x15)
    }

    @Test func respondsToBatteryCommandWithConfiguredStatus() async throws {
        let mock = MockRingTransport(batteryLevel: 88, isCharging: true)
        try await mock.connect()

        let response = try await mock.send(RingProtocol.batteryCommand())

        #expect(RingProtocol.parseBattery(response) == BatteryStatus(level: 88, isCharging: true))
    }
}
