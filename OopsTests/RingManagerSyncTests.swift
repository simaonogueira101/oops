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

    /// Verifies that per-day advancement reaches `today` when all days succeed.
    /// A mid-window failure case cannot be exercised with the current mock (it never throws),
    /// so the break-on-failure path is covered by code review only until MockRingTransport
    /// gains error-injection support.
    @MainActor
    @Test func syncAdvancesLastSyncedDayToToday() async throws {
        let container = try ModelContainer(
            for: BatteryReading.self, HeartRateSample.self, ActivitySample.self, SpO2Sample.self,
                StressSample.self, TemperatureSample.self, SleepSessionRecord.self,
                SleepStageIntervalRecord.self, RingSyncMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let manager = RingManager(transport: MockRingTransport(), modelContext: container.mainContext)
        await manager.sync()

        let metas = try container.mainContext.fetch(FetchDescriptor<RingSyncMeta>())
        let meta = try #require(metas.first)
        // sync() uses UTC day boundaries to match the ring's UTC clock.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let today = utc.startOfDay(for: .now)
        for key in ["hr", "activity", "sleep", "stress", "spo2"] {
            let advanced = meta.lastSyncedDay[key]
            #expect(advanced == today, "lastSyncedDay[\(key)] should equal today after a full successful sync")
        }
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
