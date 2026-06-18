import Foundation
import SwiftData
import Testing
@testable import Oops

struct RingManagerSyncTests {
    @MainActor
    @Test func syncPersistsBatteryLiveHRHistoryAndTemperature() async throws {
        let container = try ModelContainer(
            for: BatteryReading.self, HeartRateSample.self, ActivitySample.self, SpO2Sample.self,
                StressSample.self, TemperatureSample.self, SleepSessionRecord.self,
                SleepStageIntervalRecord.self, RingSyncMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let manager = RingManager(transport: MockRingTransport(), modelContext: container.mainContext)
        await manager.sync()
        #expect(manager.batteryStatus != nil)
        #expect(manager.liveHR != nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<HeartRateSample>()).count > 0)
        #expect(try container.mainContext.fetch(FetchDescriptor<TemperatureSample>()).count > 0)
    }

    @MainActor
    @Test func secondSyncDoesNotDuplicate() async throws {
        let container = try ModelContainer(
            for: BatteryReading.self, HeartRateSample.self, ActivitySample.self, SpO2Sample.self,
                StressSample.self, TemperatureSample.self, SleepSessionRecord.self,
                SleepStageIntervalRecord.self, RingSyncMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let manager = RingManager(transport: MockRingTransport(), modelContext: container.mainContext)
        await manager.sync()
        let first = try container.mainContext.fetch(FetchDescriptor<HeartRateSample>()).count
        await manager.sync()
        let second = try container.mainContext.fetch(FetchDescriptor<HeartRateSample>()).count
        #expect(second == first)   // dedupe holds
    }
}
