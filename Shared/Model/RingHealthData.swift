import Foundation
import SwiftData
import SwiftUI

/// SwiftData-backed `HealthData` implementation. Aggregates stored ring samples per day.
/// Metrics that require derived computation (score/recovery/strain/hrv/respiratoryRate) return
/// `nil` until a future task computes them from raw samples.
struct RingHealthData: HealthData {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - HealthData

    func dayMetrics(for date: Date) -> DayMetrics {
        let (start, end) = dayBounds(for: date)

        let activitySamples = fetchActivity(from: start, to: end)
        let hrSamples = fetchHR(from: start, to: end)
        let spo2Samples = fetchSpO2(from: start, to: end)
        let stressSamples = fetchStress(from: start, to: end)
        let tempSamples = fetchTemperature(from: start, to: end)

        let steps = activitySamples.reduce(0) { $0 + $1.steps }
        let activeCalories = activitySamples.reduce(0) { $0 + $1.calories }

        let currentHR: Int? = hrSamples.sorted { $0.timestamp > $1.timestamp }.first.map(\.bpm)
        let restingHR: Int? = hrSamples.map(\.bpm).min()

        let spo2: Int? = spo2Samples.isEmpty ? nil :
            Int(Double(spo2Samples.map(\.percent).reduce(0, +)) / Double(spo2Samples.count))
        let stress: Int? = stressSamples.isEmpty ? nil :
            Int(Double(stressSamples.map(\.value).reduce(0, +)) / Double(stressSamples.count))

        let bodyTempDelta = computeBodyTempDelta(dayStart: start, dayEnd: end, dayTemps: tempSamples)
        let sleepPerf = computeSleepPerformance(for: date)

        return DayMetrics(
            score: nil,
            recovery: nil,
            strain: nil,
            hrv: nil,
            restingHR: restingHR,
            currentHR: currentHR,
            bodyTempDelta: bodyTempDelta,
            respiratoryRate: nil,
            sleepPerformance: sleepPerf,
            steps: steps,
            stepGoal: 10_000,
            activeCalories: activeCalories,
            stress: stress,
            spo2: spo2
        )
    }

    func hrvSeries(days: Int) -> [MetricSample] { [] }

    func restingHRSeries(days: Int) -> [MetricSample] {
        buildDailySeries(days: days) { start, end in
            let samples = fetchHR(from: start, to: end)
            guard !samples.isEmpty else { return nil }
            return Double(samples.map(\.bpm).min() ?? 0)
        }
    }

    func stepsSeries(days: Int) -> [MetricSample] {
        buildDailySeries(days: days) { start, end in
            let samples = fetchActivity(from: start, to: end)
            guard !samples.isEmpty else { return nil }
            return Double(samples.reduce(0) { $0 + $1.steps })
        }
    }

    func sleepScoreSeries(days: Int) -> [MetricSample] { [] }
    func strainSeries(days: Int) -> [MetricSample] { [] }

    func sleepSession(for date: Date) -> SleepSession {
        let (start, end) = dayBounds(for: date)
        var descriptor = FetchDescriptor<SleepSessionRecord>(
            predicate: #Predicate { $0.dayStart >= start && $0.dayStart < end }
        )
        descriptor.fetchLimit = 1
        guard let record = (try? modelContext.fetch(descriptor))?.first else {
            return SleepSession(intervals: [])
        }
        let intervals: [SleepStageInterval] = record.intervals.compactMap { iv in
            guard let stage = sleepStage(fromRaw: iv.stageRaw) else { return nil }
            return SleepStageInterval(stage: stage, start: iv.start, end: iv.end)
        }
        return SleepSession(intervals: intervals)
    }

    func hrZones(for date: Date) -> [HRZone] {
        let (start, end) = dayBounds(for: date)
        let samples = fetchHR(from: start, to: end)
        guard !samples.isEmpty else { return [] }

        let zones: [(String, Int, Int, Double)] = [
            ("Light", 95, 114, 0.35),
            ("Moderate", 115, 132, 0.55),
            ("Hard", 133, 151, 0.75),
            ("Peak", 152, 220, 1.0)
        ]
        return zones.map { name, lo, hi, opacity in
            let minutes = samples.filter { $0.bpm >= lo && $0.bpm <= hi }.count
            return HRZone(name: name, lowerBPM: lo, upperBPM: hi, minutes: minutes,
                          color: AppColor.strain.opacity(opacity))
        }
    }

    // MARK: - Private fetch helpers

    private func dayBounds(for date: Date) -> (Date, Date) {
        let start = Calendar.current.startOfDay(for: date)
        return (start, start.addingTimeInterval(86_400))
    }

    private func fetchActivity(from start: Date, to end: Date) -> [ActivitySample] {
        let descriptor = FetchDescriptor<ActivitySample>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchHR(from start: Date, to end: Date) -> [HeartRateSample] {
        let descriptor = FetchDescriptor<HeartRateSample>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchSpO2(from start: Date, to end: Date) -> [SpO2Sample] {
        let descriptor = FetchDescriptor<SpO2Sample>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchStress(from start: Date, to end: Date) -> [StressSample] {
        let descriptor = FetchDescriptor<StressSample>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchTemperature(from start: Date, to end: Date) -> [TemperatureSample] {
        let descriptor = FetchDescriptor<TemperatureSample>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func buildDailySeries(days: Int, value: (Date, Date) -> Double?) -> [MetricSample] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<days).compactMap { offset -> MetricSample? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let (start, end) = dayBounds(for: day)
            guard let v = value(start, end) else { return nil }
            return MetricSample(date: day, value: v)
        }.reversed()
    }

    // MARK: - Derived metric helpers

    private func computeBodyTempDelta(dayStart: Date, dayEnd: Date,
                                      dayTemps: [TemperatureSample]) -> Double? {
        guard !dayTemps.isEmpty else { return nil }
        let dayMean = dayTemps.map(\.celsius).reduce(0, +) / Double(dayTemps.count)

        guard let baselineStart = Calendar.current.date(byAdding: .day, value: -7, to: dayStart) else {
            return nil
        }
        let baselineSamples = fetchTemperature(from: baselineStart, to: dayStart)
        guard !baselineSamples.isEmpty else { return nil }
        let baselineMean = baselineSamples.map(\.celsius).reduce(0, +) / Double(baselineSamples.count)
        return dayMean - baselineMean
    }

    private func computeSleepPerformance(for date: Date) -> Double {
        let session = sleepSession(for: date)
        guard session.timeInBed > 0 else { return 0 }
        let goalSeconds: TimeInterval = 8 * 3600
        return min(session.totalAsleep / goalSeconds, 1.0)
    }

    /// Maps the integer `stageRaw` stored in `SleepStageIntervalRecord` to a `SleepStage`.
    /// Convention matches `SleepStage.row`: 0 = awake, 1 = rem, 2 = light, 3 = deep.
    private func sleepStage(fromRaw raw: Int) -> SleepStage? {
        switch raw {
        case 0: return .awake
        case 1: return .rem
        case 2: return .light
        case 3: return .deep
        default: return nil
        }
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var healthData: any HealthData = MockHealthData()
}

// MARK: - Dash formatting helpers

/// Returns a formatted string for an optional Int metric, or "—" if nil.
func dashFormatted(_ value: Int?) -> String {
    guard let value else { return "—" }
    return "\(value)"
}

/// Returns a formatted string for an optional Double metric, or "—" if nil.
func dashFormatted(_ value: Double?, precision: Int = 1) -> String {
    guard let value else { return "—" }
    return value.formatted(.number.precision(.fractionLength(precision)))
}
