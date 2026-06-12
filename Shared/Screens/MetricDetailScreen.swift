import SwiftUI

/// A reusable vitals detail screen: pinned period picker, a trend chart driven by the selected
/// window, summary stats, and an explainer. One template serves HRV, resting HR, body temp,
/// and respiratory rate.
struct MetricDetailScreen: View {
    let title: String
    let accent: Color
    let unit: String
    let currentValue: String
    let baseline: Double
    /// Generates the series for a day count — the period picker drives it.
    let series: (Int) -> [MetricSample]
    let about: String
    @State private var period: Period = .week

    private var samples: [MetricSample] { series(period.days) }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Card(label: title, title: currentValue, accent: accent) {
                    LineTrendChart(samples: samples, color: accent, baseline: baseline)
                }

                Card(label: "Statistics") {
                    HStack {
                        StatTile(label: "Average", value: average, unit: unit)
                        StatTile(label: "Baseline", value: Int(baseline).formatted(.number), unit: unit)
                    }
                }

                Card(label: "About \(title)") {
                    Text(about).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
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
        .drawerTitle(title)
    }

    private var average: String {
        guard !samples.isEmpty else { return "–" }
        let mean = samples.map(\.value).reduce(0, +) / Double(samples.count)
        return Int(mean).formatted(.number)
    }
}

extension MetricDetailScreen {
    static func hrv() -> MetricDetailScreen {
        .init(title: "HRV", accent: AppColor.recovery, unit: "ms", currentValue: "48 ms",
              baseline: 44, series: { MockHealthData().hrvSeries(days: $0) },
              about: "Heart-rate variability reflects how recovered and adaptable your nervous system is.")
    }
    static func heartRate() -> MetricDetailScreen {
        .init(title: "Resting Heart Rate", accent: AppColor.recovery, unit: "bpm", currentValue: "54 bpm",
              baseline: 56, series: { MockHealthData().restingHRSeries(days: $0) },
              about: "Your resting heart rate is a window into cardiovascular health and recovery.")
    }
    static func bodyTemp() -> MetricDetailScreen {
        .init(title: "Skin Temperature", accent: AppColor.recovery, unit: "°C", currentValue: "−0.2 °C",
              baseline: 0, series: { MockHealthData().series(days: $0, base: 0, spread: 0.8) },
              about: "Nightly skin-temperature deviation from your baseline can flag strain or illness.")
    }
    static func respiratory() -> MetricDetailScreen {
        .init(title: "Respiratory Rate", accent: AppColor.recovery, unit: "br/min", currentValue: "14.1",
              baseline: 14, series: { MockHealthData().series(days: $0, base: 14, spread: 2) },
              about: "Breaths per minute during sleep is typically stable; changes can signal strain.")
    }
}

#Preview {
    NavigationStack { MetricDetailScreen.hrv() }
}
