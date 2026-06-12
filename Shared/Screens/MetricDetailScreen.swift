import SwiftUI

/// A reusable vitals detail screen: period picker, a trend chart, summary stats, and an
/// explainer. One template serves HRV, resting HR, SpO₂, stress, body temp, and respiratory rate.
struct MetricDetailScreen: View {
    let title: String
    let accent: Color
    let unit: String
    let currentValue: String
    let baseline: Double
    let samples: [MetricSample]
    let about: String
    @State private var period: Period = .week

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                PeriodPicker(period: $period)

                Card(label: title, title: currentValue, accent: accent) {
                    LineTrendChart(samples: samples, color: accent, baseline: baseline)
                }

                Card(label: "Statistics") {
                    HStack {
                        StatTile(label: "Average", value: average, accent: accent)
                        StatTile(label: "Baseline", value: "\(Int(baseline)) \(unit)")
                    }
                }

                Card(label: "About \(title)") {
                    Text(about).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .inlineNavigationTitle(title)
    }

    private var average: String {
        guard !samples.isEmpty else { return "–" }
        let mean = samples.map(\.value).reduce(0, +) / Double(samples.count)
        return "\(Int(mean)) \(unit)"
    }
}

extension MetricDetailScreen {
    static func hrv() -> MetricDetailScreen {
        .init(title: "HRV", accent: AppColor.recovery, unit: "ms", currentValue: "48 ms",
              baseline: 44, samples: MockHealthData().hrvSeries(days: 14),
              about: "Heart-rate variability reflects how recovered and adaptable your nervous system is.")
    }
    static func heartRate() -> MetricDetailScreen {
        .init(title: "Heart Rate", accent: AppColor.recovery, unit: "bpm", currentValue: "61 bpm",
              baseline: 54, samples: MockHealthData().restingHRSeries(days: 14),
              about: "Your resting heart rate is a window into cardiovascular health and recovery.")
    }
    static func bodyTemp() -> MetricDetailScreen {
        .init(title: "Skin Temperature", accent: AppColor.recovery, unit: "°C", currentValue: "−0.2 °C",
              baseline: 0, samples: MockHealthData().series(days: 14, base: 0, spread: 0.8),
              about: "Nightly skin-temperature deviation from your baseline can flag strain or illness.")
    }
    static func respiratory() -> MetricDetailScreen {
        .init(title: "Respiratory Rate", accent: AppColor.recovery, unit: "br/min", currentValue: "14.1",
              baseline: 14, samples: MockHealthData().series(days: 14, base: 14, spread: 2),
              about: "Breaths per minute during sleep is typically stable; changes can signal strain.")
    }
}

#Preview {
    NavigationStack { MetricDetailScreen.hrv() }
}
