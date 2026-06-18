import Foundation
import SwiftData
import Testing
@testable import Oops

struct RingPersistenceTests {
    @MainActor
    @Test func insertsAndFetchesHeartRateAndTemperature() throws {
        let container = try ModelContainer(
            for: HeartRateSample.self, ActivitySample.self, SpO2Sample.self, StressSample.self,
                TemperatureSample.self, SleepSessionRecord.self, SleepStageIntervalRecord.self, RingSyncMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        ctx.insert(HeartRateSample(timestamp: .init(timeIntervalSince1970: 1), bpm: 60))
        ctx.insert(TemperatureSample(timestamp: .init(timeIntervalSince1970: 1), celsius: 36.5))
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<HeartRateSample>()).first?.bpm == 60)
        #expect(try ctx.fetch(FetchDescriptor<TemperatureSample>()).first?.celsius == 36.5)
    }
}
