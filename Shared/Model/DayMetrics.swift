import Foundation

/// Headline daily metrics shown across the app. Placeholder values come from `MockHealthData`
/// until the ring provides real recovery/strain/sleep data.
struct DayMetrics: Equatable {
    var score: Int?                // 0...100 overall (recovery-style); nil until ring data lands
    var recovery: Double?          // 0...1; nil until ring data lands
    var strain: Double?            // 0...21 (Whoop-like scale); nil until ring data lands
    var hrv: Int?                  // ms; nil until ring data lands
    var restingHR: Int?             // bpm; nil when no samples
    var currentHR: Int?             // bpm, latest reading; nil when no samples
    var bodyTempDelta: Double?     // °C deviation from baseline; nil when no temperature data
    var bodyTemp: Double?          // °C, the day's average skin temperature; nil when no data
    var respiratoryRate: Double?   // breaths / min; nil until ring data lands
    var sleepPerformance: Double   // 0...1
    var steps: Int
    var stepGoal: Int
    var activeCalories: Int
    var distanceMeters: Int        // total distance for the day, from the ring's activity log
    var stress: Int?                // 0...100; nil when no samples
    var spo2: Int?                  // %; nil when no samples

    /// Strain mapped to 0...1 for the ring.
    var strainFraction: Double { min(max((strain ?? 0) / 21, 0), 1) }

    static let sample = MockHealthData().dayMetrics(for: .now)
}
