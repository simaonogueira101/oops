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

    @MainActor
    @Test func aggregatesDistanceAndAveragesBodyTemp() throws {
        let container = try ModelContainer(
            for: HeartRateSample.self, ActivitySample.self, SpO2Sample.self, StressSample.self,
                TemperatureSample.self, SleepSessionRecord.self, SleepStageIntervalRecord.self, RingSyncMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: .now)
        ctx.insert(ActivitySample(timestamp: day, steps: 100, calories: 5, distanceMeters: 70))
        ctx.insert(ActivitySample(timestamp: day.addingTimeInterval(900), steps: 150, calories: 7, distanceMeters: 110))
        ctx.insert(TemperatureSample(timestamp: day.addingTimeInterval(3600), celsius: 36.0))
        ctx.insert(TemperatureSample(timestamp: day.addingTimeInterval(7200), celsius: 37.0))
        try ctx.save()
        let m = RingHealthData(modelContext: ctx).dayMetrics(for: day)
        #expect(m.distanceMeters == 180)        // 70 + 110, summed
        #expect(m.bodyTemp == 36.5)             // (36.0 + 37.0) / 2, averaged

        // A day with no temperature samples → bodyTemp is nil (renders "—"), not a fabricated 0.
        let empty = RingHealthData(modelContext: ctx).dayMetrics(for: day.addingTimeInterval(-86400))
        #expect(empty.bodyTemp == nil)
        #expect(empty.distanceMeters == 0)
    }
}
