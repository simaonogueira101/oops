import Foundation

/// Headline daily metrics shown across the app. Placeholder values come from `MockHealthData`
/// until the ring provides real recovery/strain/sleep data.
struct DayMetrics: Equatable {
    var score: Int                // 0...100 overall (recovery-style)
    var recovery: Double          // 0...1
    var strain: Double            // 0...21 (Whoop-like scale)
    var hrv: Int                  // ms
    var restingHR: Int            // bpm
    var currentHR: Int            // bpm, latest reading
    var bodyTempDelta: Double     // °C deviation from baseline
    var respiratoryRate: Double   // breaths / min
    var sleepPerformance: Double  // 0...1
    var steps: Int
    var stepGoal: Int
    var activeCalories: Int
    var stress: Int               // 0...100
    var spo2: Int                 // %

    /// Strain mapped to 0...1 for the ring.
    var strainFraction: Double { min(max(strain / 21, 0), 1) }

    static let sample = MockHealthData().dayMetrics
}
