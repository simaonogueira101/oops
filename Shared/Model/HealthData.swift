import Foundation

/// Abstraction over a health-data source. `MockHealthData` is the only conformer today;
/// a ring-backed implementation will follow in a later task.
protocol HealthData {
    func dayMetrics(for date: Date) -> DayMetrics
    func hrvSeries(days: Int) -> [MetricSample]
    func restingHRSeries(days: Int) -> [MetricSample]
    func stepsSeries(days: Int) -> [MetricSample]
    func sleepScoreSeries(days: Int) -> [MetricSample]
    func strainSeries(days: Int) -> [MetricSample]
    func heartRateSeries(days: Int) -> [MetricSample]
    func spo2Series(days: Int) -> [MetricSample]
    func stressSeries(days: Int) -> [MetricSample]
    func temperatureSeries(days: Int) -> [MetricSample]
    func sleepSession(for date: Date) -> SleepSession
    func hrZones(for date: Date) -> [HRZone]
}
