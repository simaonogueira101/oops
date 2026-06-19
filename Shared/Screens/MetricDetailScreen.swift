import SwiftUI

/// A reusable vitals detail screen: pinned period picker, a trend chart driven by the selected
/// window, summary stats, and an explainer. One template serves every vital, reading real ring
/// samples through the injected `HealthData`.
struct MetricDetailScreen: View {
    /// The vital this screen renders. Knows its title, accent, unit, series selector, the value
    /// for today, and its explainer — so the screen stays a thin shell over real data.
    enum Metric {
        case heartRate, hrv, restingHR, bodyTemp, respiratory, bloodOxygen, stress

        var title: String {
            switch self {
            case .heartRate: return "Heart Rate"
            case .hrv: return "HRV"
            case .restingHR: return "Resting Heart Rate"
            case .bodyTemp: return "Skin Temperature"
            case .respiratory: return "Respiratory Rate"
            case .bloodOxygen: return "Blood Oxygen"
            case .stress: return "Stress"
            }
        }

        var accent: Color { AppColor.recovery }

        var unit: String {
            switch self {
            case .heartRate, .restingHR: return "bpm"
            case .hrv: return "ms"
            case .bodyTemp: return "°C"
            case .respiratory: return "br/min"
            case .bloodOxygen: return "%"
            case .stress: return ""
            }
        }

        var about: String {
            switch self {
            case .heartRate:
                return "Your heart rate through the day reflects exertion, stress, and recovery."
            case .hrv:
                return "Heart-rate variability reflects how recovered and adaptable your nervous system is."
            case .restingHR:
                return "Your resting heart rate is a window into cardiovascular health and recovery."
            case .bodyTemp:
                return "Nightly skin-temperature deviation from your baseline can flag strain or illness."
            case .respiratory:
                return "Breaths per minute during sleep is typically stable; changes can signal strain."
            case .bloodOxygen:
                return "Blood oxygen (SpO₂) is the percentage of oxygen your red blood cells carry; the ring samples it through the day and overnight."
            case .stress:
                return "Stress is estimated from heart-rate variability; lower values mean a calmer nervous system."
            }
        }

        func series(_ health: any HealthData, _ days: Int) -> [MetricSample] {
            switch self {
            case .heartRate: return health.heartRateSeries(days: days)
            case .hrv: return health.hrvSeries(days: days)
            case .restingHR: return health.restingHRSeries(days: days)
            case .bodyTemp: return health.temperatureSeries(days: days)
            case .respiratory: return []
            case .bloodOxygen: return health.spo2Series(days: days)
            case .stress: return health.stressSeries(days: days)
            }
        }

        /// Today's headline value, formatted with the unit, or "—" when no sample exists.
        func currentValue(_ metrics: DayMetrics) -> String {
            switch self {
            case .heartRate:
                return metrics.currentHR.map { "\($0) bpm" } ?? "—"
            case .hrv:
                return metrics.hrv.map { "\($0) ms" } ?? "—"
            case .restingHR:
                return metrics.restingHR.map { "\($0) bpm" } ?? "—"
            case .bodyTemp:
                guard let delta = metrics.bodyTempDelta else { return "—" }
                let sign = delta >= 0 ? "+" : ""
                return "\(sign)\(delta.formatted(.number.precision(.fractionLength(1)))) °C"
            case .respiratory:
                return metrics.respiratoryRate.map { dashFormatted($0) } ?? "—"
            case .bloodOxygen:
                return metrics.spo2.map { "\($0)%" } ?? "—"
            case .stress:
                return metrics.stress.map { "\($0)" } ?? "—"
            }
        }
    }

    let metric: Metric
    @State private var period: Period = .week
    @Environment(\.healthData) private var health

    private var samples: [MetricSample] { metric.series(health, period.days) }
    private var metrics: DayMetrics { health.dayMetrics(for: .now) }
    private var currentValue: String { metric.currentValue(metrics) }
    /// Series average as the trend baseline; nil hides the baseline line and the stat tile.
    private var baseline: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.map(\.value).reduce(0, +) / Double(samples.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Card(label: metric.title, title: currentValue, accent: metric.accent) {
                    BarSeriesChart(samples: samples, period: period,
                                   color: metric.accent, baseline: baseline)
                }

                Card(label: "Statistics") {
                    HStack {
                        StatTile(label: "Average", value: average, unit: metric.unit)
                        if let baseline {
                            StatTile(label: "Baseline", value: Int(baseline).formatted(.number), unit: metric.unit)
                        }
                    }
                }

                Card(label: "About \(metric.title)") {
                    Text(metric.about).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
                }
            }
            .padding(Spacing.md)
            .animation(.snappy, value: period)
        }
        .safeAreaInset(edge: .top) {
            PeriodPicker(period: $period)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xs)
        }
        .sensoryFeedback(.selection, trigger: period)
        .background(AppColor.background)
        .drawerTitle(metric.title)
    }

    private var average: String {
        guard !samples.isEmpty else { return "–" }
        let mean = samples.map(\.value).reduce(0, +) / Double(samples.count)
        return Int(mean).formatted(.number)
    }
}

extension MetricDetailScreen {
    static func hrv() -> MetricDetailScreen { .init(metric: .hrv) }
    static func heartRate() -> MetricDetailScreen { .init(metric: .restingHR) }
    static func bodyTemp() -> MetricDetailScreen { .init(metric: .bodyTemp) }
    static func respiratory() -> MetricDetailScreen { .init(metric: .respiratory) }
    static func bloodOxygen() -> MetricDetailScreen { .init(metric: .bloodOxygen) }
    static func stress() -> MetricDetailScreen { .init(metric: .stress) }
}

#Preview {
    NavigationStack { MetricDetailScreen.hrv() }
        .environment(\.healthData, MockHealthData())
}
