import Foundation
import SwiftData
import Testing
@testable import Oops

struct RingManagerSyncTests {
    @MainActor
    @Test func syncPersistsBatteryLiveHRHistoryAndTemperature() async throws {
        let container = try ModelContainer(
            for: BatteryReading.self, HeartRateSample.self, ActivitySample.self, SpO2Sample.self,
                StressSample.self, TemperatureSample.self, HRVSample.self, SleepSessionRecord.self,
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
                StressSample.self, TemperatureSample.self, HRVSample.self, SleepSessionRecord.self,
                SleepStageIntervalRecord.self, RingSyncMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let manager = RingManager(transport: MockRingTransport(), modelContext: container.mainContext)
        await manager.sync()

        let metas = try container.mainContext.fetch(FetchDescriptor<RingSyncMeta>())
        let meta = try #require(metas.first)
        // sync() uses local day boundaries (Calendar.current) to match the ring's local clock.
        let today = Calendar.current.startOfDay(for: .now)
        for key in ["hr", "activity", "sleep", "stress", "spo2", "hrv"] {
            let advanced = meta.lastSyncedDay[key]
            #expect(advanced == today, "lastSyncedDay[\(key)] should equal today after a full successful sync")
        }
    }

    /// SpO2's big V2 response often arrives AFTER its own read times out, so the live read yields
    /// nothing and the data must be recovered from the transport's late-response cache. Exercises
    /// RingManager's cache-drain path (the SpO2-showed-no-data fix).
    @MainActor
    @Test func recoversSpO2FromLateResponseCache() async throws {
        let container = try ModelContainer(
            for: BatteryReading.self, HeartRateSample.self, ActivitySample.self, SpO2Sample.self,
                StressSample.self, TemperatureSample.self, HRVSample.self, SleepSessionRecord.self,
                SleepStageIntervalRecord.self, RingSyncMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let mock = MockRingTransport()
        mock.spo2LiveReturnsEmpty = true   // live read returns nothing — only the cache has data
        // A real captured BC2A SpO2 response (97% values), same fixture as RingV2RealCaptureTests.
        let spo2Hex = "bc2a62006b060100000000000000000000000000000000000000000000000000000000000000000000000000000000000000006161616100606060606363606060606060616100000000616100000000616100000000000000000000000000000000000000000000"
        var data = Data(); var i = spo2Hex.startIndex
        while i < spo2Hex.endIndex {
            let j = spo2Hex.index(i, offsetBy: 2)
            data.append(UInt8(spo2Hex[i..<j], radix: 16)!); i = j
        }
        mock.cachedBigData[0x2A] = [data]
        let manager = RingManager(transport: mock, modelContext: container.mainContext)
        await manager.sync()
        #expect(try container.mainContext.fetch(FetchDescriptor<SpO2Sample>()).count > 0,
                "SpO2 should be recovered from the late-response cache when the live read is empty")
    }

    @MainActor
    @Test func secondSyncDoesNotDuplicate() async throws {
        let container = try ModelContainer(
            for: BatteryReading.self, HeartRateSample.self, ActivitySample.self, SpO2Sample.self,
                StressSample.self, TemperatureSample.self, HRVSample.self, SleepSessionRecord.self,
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
