import Foundation
import Testing
@testable import Oops

@MainActor
struct MockRingTransportTests {
    @Test func respondsToBatteryCommandWithConfiguredStatus() async throws {
        let mock = MockRingTransport(batteryLevel: 88, isCharging: true)
        try await mock.connect()

        let response = try await mock.send(RingProtocol.batteryCommand())

        #expect(RingProtocol.parseBattery(response) == BatteryStatus(level: 88, isCharging: true))
    }
}
