import Foundation
import SwiftData
import Testing
@testable import Oops

@MainActor
struct RingManagerTests {
    private func inMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: BatteryReading.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func refreshBatteryReadsAndPersists() async throws {
        let context = try inMemoryContext()
        let manager = RingManager(
            transport: MockRingTransport(batteryLevel: 64, isCharging: true),
            modelContext: context
        )

        await manager.refreshBattery()

        #expect(manager.batteryStatus == BatteryStatus(level: 64, isCharging: true))
        #expect(manager.lastUpdated != nil)
        #expect(manager.errorMessage == nil)

        let saved = try context.fetch(FetchDescriptor<BatteryReading>())
        #expect(saved.count == 1)
        #expect(saved.first?.level == 64)
        #expect(saved.first?.isCharging == true)
    }
}
