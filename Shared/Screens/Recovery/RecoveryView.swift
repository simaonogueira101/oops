import SwiftUI

/// The Recovery tab: the recovery score, its contributors, and the vitals that feed it — each
/// a `Card` that deep-links into a detail screen.
struct RecoveryView: View {
    var date: Date = .now
    @State private var period: Period = .week
    @Environment(\.healthData) private var health
    private var metrics: DayMetrics { health.dayMetrics(for: date) }
    private var band: ScoreBand { ScoreBand(score: metrics.score ?? 0) }

    private var bodyTempAccessory: String {
        guard let delta = metrics.bodyTempDelta else { return "—" }
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(delta.formatted(.number.precision(.fractionLength(1)))) °C"
    }

    var body: some View {
        TopScrollView {
            VStack(spacing: Spacing.md) {
                PageHeader(title: "Recovery")
                scoreHero
                contributorsCard
                hrvCard
                restingHRCard
                bodyTempCard
                bloodOxygenCard
                stressCard
                respiratoryCard
                trendsCard
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
    }

    private var scoreHero: some View {
        Card(label: "Recovery", accent: AppColor.recovery) {
            HStack(spacing: Spacing.lg) {
                ScoreRing(score: metrics.score ?? 0, accent: AppColor.recovery,
                          caption: metrics.score != nil ? band.label : nil, size: 120)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("HRV \(dashFormatted(metrics.hrv)) ms").font(.subheadline)
                    Text("RHR \(dashFormatted(metrics.restingHR)) bpm").font(.subheadline)
                }
            }
        }
    }

    private var contributorsCard: some View {
        // Contributors require derived computation not yet available from raw ring samples.
        // Render the named rows as unavailable (—) rather than fabricating values.
        Card(label: "Contributors") {
            ContributorRows(tint: AppColor.recovery, contributors: [
                Contributor(name: "HRV balance", fraction: nil, band: nil),
                Contributor(name: "Resting heart rate", fraction: nil, band: nil),
                Contributor(name: "Body temperature", fraction: nil, band: nil),
                Contributor(name: "Recovery index", fraction: nil, band: nil),
                Contributor(name: "Sleep balance", fraction: nil, band: nil),
                Contributor(name: "Activity balance", fraction: nil, band: nil)
            ])
        }
    }

    private var hrvCard: some View {
        Card(label: "HRV", accent: AppColor.recovery,
             accessory: .value(metrics.hrv.map { "\($0) ms" } ?? "—"),
             showsChevron: true) {
            Sparkline(samples: health.hrvSeries(days: 14), color: AppColor.recovery)
        }
        .navigates(to: .hrv)
    }

    private var restingHRCard: some View {
        Card(label: "Resting heart rate", accent: AppColor.recovery,
             accessory: .value(metrics.restingHR.map { "\($0) bpm" } ?? "—"),
             showsChevron: true) {
            Sparkline(samples: health.restingHRSeries(days: 14), color: AppColor.recovery)
        }
        .navigates(to: .heartRate)
    }

    private var bodyTempCard: some View {
        Card(label: "Skin temperature", accent: AppColor.recovery, accessory: .value(bodyTempAccessory), showsChevron: true) {
            Sparkline(samples: health.temperatureSeries(days: 14), color: AppColor.recovery)
        }
        .navigates(to: .bodyTemp)
    }

    private var bloodOxygenCard: some View {
        Card(label: "Blood oxygen", accent: AppColor.recovery,
             accessory: .value(metrics.spo2.map { "\($0)%" } ?? "—"), showsChevron: true) {
            Sparkline(samples: health.spo2Series(days: 14), color: AppColor.recovery)
        }
        .navigates(to: .bloodOxygen)
    }

    private var stressCard: some View {
        Card(label: "Stress", accent: AppColor.recovery,
             accessory: .value(metrics.stress.map { "\($0)" } ?? "—"), showsChevron: true) {
            Sparkline(samples: health.stressSeries(days: 14), color: AppColor.recovery)
        }
        .navigates(to: .stress)
    }

    private var respiratoryCard: some View {
        Card(label: "Respiratory rate", accent: AppColor.recovery,
             accessory: .value(dashFormatted(metrics.respiratoryRate)), showsChevron: true) {
            Sparkline(samples: [], color: AppColor.recovery)
        }
        .navigates(to: .respiratory)
    }

    private var trendsCard: some View {
        Card(label: "Recovery trends") {
            VStack(spacing: Spacing.sm) {
                PeriodPicker(period: $period)
                LineTrendChart(samples: health.restingHRSeries(days: period.days),
                               color: AppColor.recovery, baseline: nil)
                    .animation(.snappy, value: period)
            }
        }
    }
}

#Preview {
    NavigationStack { RecoveryView() }
}
