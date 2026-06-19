import Foundation

/// Deterministic sample data for every screen. Seeded so previews and tests are stable — it never
/// reads the wall clock or `random()`. Swap for a real ring-backed provider later.
struct MockHealthData: HealthData {
    private let seed: UInt64
    /// Fixed reference midnight so output never depends on the current date.
    let referenceDate: Date

    init(seed: UInt64 = 7) {
        self.seed = seed
        referenceDate = Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 0))!
    }

    // MARK: Scores

    /// `HealthData` conformance — date is ignored; output is always deterministic.
    func dayMetrics(for date: Date) -> DayMetrics {
        DayMetrics(score: 72, recovery: 0.72, strain: 8.4, hrv: 48, restingHR: 54, currentHR: 61,
                   bodyTempDelta: -0.2, respiratoryRate: 14.1, sleepPerformance: 0.86,
                   steps: 9240, stepGoal: 12000, activeCalories: 430, distanceMeters: 6800,
                   stress: 32, spo2: 97)
    }

    /// Convenience accessor kept for existing screen code that doesn't have a date context.
    var dayMetrics: DayMetrics { dayMetrics(for: referenceDate) }

    // MARK: Series

    func hrvSeries(days: Int) -> [MetricSample] { series(days: days, base: 45, spread: 18) }
    func restingHRSeries(days: Int) -> [MetricSample] { series(days: days, base: 55, spread: 6) }
    func stepsSeries(days: Int) -> [MetricSample] { series(days: days, base: 9000, spread: 4000) }
    func sleepScoreSeries(days: Int) -> [MetricSample] { series(days: days, base: 84, spread: 14) }
    func strainSeries(days: Int) -> [MetricSample] { series(days: days, base: 9, spread: 8) }
    func heartRateSeries(days: Int) -> [MetricSample] { series(days: days, base: 64, spread: 12) }
    func spo2Series(days: Int) -> [MetricSample] { series(days: days, base: 97, spread: 2) }
    func stressSeries(days: Int) -> [MetricSample] { series(days: days, base: 32, spread: 20) }
    func temperatureSeries(days: Int) -> [MetricSample] { series(days: days, base: 36.5, spread: 0.6) }

    /// `days` daily samples ending at `referenceDate`, jittered deterministically around `base`.
    func series(days: Int, base: Double, spread: Double) -> [MetricSample] {
        var gen = LCG(seed: seed &+ UInt64(bitPattern: Int64(base.bitPattern)))
        return (0..<days).reversed().map { offset in
            let jitter = (gen.nextUnit() - 0.5) * spread
            return MetricSample(date: referenceDate.addingTimeInterval(Double(-offset) * 86_400),
                                value: base + jitter)
        }
    }

    // MARK: Sleep — contiguous intervals from bedtime

    /// `HealthData` conformance — date is ignored; output is always deterministic.
    func sleepSession(for date: Date) -> SleepSession { sleepSession() }

    func sleepSession() -> SleepSession {
        var gen = LCG(seed: seed)
        let bedtime = referenceDate.addingTimeInterval(-1 * 3600) // ~23:00 the night before
        let pattern: [(SleepStage, Int)] = [
            (.awake, 6), (.light, 35), (.deep, 40), (.light, 25), (.rem, 20),
            (.light, 30), (.deep, 25), (.rem, 30), (.light, 20), (.rem, 25), (.awake, 4)
        ]
        var cursor = bedtime
        var intervals: [SleepStageInterval] = []
        for (stage, minutes) in pattern {
            let wobble = Int((gen.nextUnit() - 0.5) * 8)
            let mins = max(3, minutes + wobble)
            let end = cursor.addingTimeInterval(Double(mins) * 60)
            intervals.append(SleepStageInterval(stage: stage, start: cursor, end: end))
            cursor = end
        }
        return SleepSession(intervals: intervals)
    }

    /// Minute-spaced HR samples across a workout's actual window (≤60 samples).
    func workoutHRSeries(start: Date, duration: TimeInterval, avgHR: Int) -> [MetricSample] {
        var gen = LCG(seed: seed &+ UInt64(max(0, Int(start.timeIntervalSince1970))))
        let count = max(2, min(60, Int(duration / 60)))
        let step = duration / Double(count - 1)
        return (0..<count).map { index in
            let jitter = (gen.nextUnit() - 0.5) * 30
            return MetricSample(date: start.addingTimeInterval(Double(index) * step),
                                value: Double(avgHR) + jitter)
        }
    }

    // MARK: Zones, workouts, tags

    /// `HealthData` conformance — date is ignored; output is always deterministic.
    func hrZones(for date: Date) -> [HRZone] { hrZones() }

    func hrZones() -> [HRZone] {
        // A strain-hue intensity ramp — the status trio keeps meaning good/warn/bad app-wide.
        [HRZone(name: "Light", lowerBPM: 95, upperBPM: 114, minutes: 38, color: AppColor.strain.opacity(0.35)),
         HRZone(name: "Moderate", lowerBPM: 115, upperBPM: 132, minutes: 17, color: AppColor.strain.opacity(0.55)),
         HRZone(name: "Hard", lowerBPM: 133, upperBPM: 151, minutes: 9, color: AppColor.strain.opacity(0.75)),
         HRZone(name: "Peak", lowerBPM: 152, upperBPM: 200, minutes: 3, color: AppColor.strain)]
    }

}

/// Tiny deterministic PRNG (value type, no Foundation randomness).
struct LCG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
