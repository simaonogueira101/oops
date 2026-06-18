import Foundation
import SwiftData
import Testing
@testable import Oops

struct RingHealthDataTests {
    @MainActor
    @Test func aggregatesStepsForADay() throws {
        let container = try ModelContainer(
            for: HeartRateSample.self, ActivitySample.self, SpO2Sample.self, StressSample.self,
                TemperatureSample.self, SleepSessionRecord.self, SleepStageIntervalRecord.self, RingSyncMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: .now)
        ctx.insert(ActivitySample(timestamp: day, steps: 100, calories: 5, distanceMeters: 70))
        ctx.insert(ActivitySample(timestamp: day.addingTimeInterval(900), steps: 150, calories: 7, distanceMeters: 110))
        ctx.insert(TemperatureSample(timestamp: day.addingTimeInterval(3600), celsius: 34.0))
        try ctx.save()
        let provider = RingHealthData(modelContext: ctx)
        #expect(provider.dayMetrics(for: day).steps == 250)
    }
}
