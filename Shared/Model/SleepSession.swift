import Foundation

/// A night of sleep as an ordered set of stage intervals, with aggregate math.
struct SleepSession: Equatable {
    let intervals: [SleepStageInterval]

    var timeInBed: TimeInterval { intervals.reduce(0) { $0 + $1.duration } }
    var totalAsleep: TimeInterval {
        intervals.filter { $0.stage != .awake }.reduce(0) { $0 + $1.duration }
    }
    var start: Date? { intervals.map(\.start).min() }
    var end: Date? { intervals.map(\.end).max() }

    func duration(of stage: SleepStage) -> TimeInterval {
        intervals.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }

    /// Whole-percent of *time asleep* (awake excluded from the denominator).
    func percentage(of stage: SleepStage) -> Int {
        guard totalAsleep > 0, stage != .awake else { return 0 }
        return Int((duration(of: stage) / totalAsleep * 100).rounded())
    }
}
