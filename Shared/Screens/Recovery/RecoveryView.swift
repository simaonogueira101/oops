import SwiftUI

/// The Recovery tab: the recovery score, its contributors, and the vitals that feed it — each
/// a `Card` that deep-links into a detail screen.
struct RecoveryView: View {
    @State private var period: Period = .week
    private var mock: MockHealthData { MockHealthData() }
    private var band: ScoreBand { ScoreBand(score: 72) }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                scoreHero
                contributorsCard
                hrvCard
                restingHRCard
                bodyTempCard
                respiratoryCard
                trendsCard
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .navigationTitle("Recovery")
    }

    private var scoreHero: some View {
        Card(label: "Recovery", title: band.label, accent: AppColor.recovery) {
            HStack(spacing: Spacing.lg) {
                ScoreRing(score: 72, accent: AppColor.recovery, caption: band.label, size: 120)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("HRV 48 ms").font(.subheadline)
                    Text("RHR 54 bpm").font(.subheadline)
                }
            }
        }
    }

    private var contributorsCard: some View {
        Card(label: "Contributors") {
            ContributorRows(contributors: [
                Contributor(name: "HRV balance", fraction: 0.8, band: .good),
                Contributor(name: "Resting heart rate", fraction: 0.9, band: .optimal),
                Contributor(name: "Body temperature", fraction: 0.5, band: .fair),
                Contributor(name: "Recovery index", fraction: 0.85, band: .optimal),
                Contributor(name: "Sleep balance", fraction: 0.7, band: .good),
                Contributor(name: "Activity balance", fraction: 0.6, band: .good)
            ])
        }
    }

    private var hrvCard: some View {
        Card(label: "HRV", accent: AppColor.recovery,
             accessory: .delta(DeltaInfo(value: 48, baseline: 44), upIsGood: true)) {
            Sparkline(samples: mock.hrvSeries(days: 14), color: AppColor.recovery)
        }
        .navigates(to: .hrv)
    }

    private var restingHRCard: some View {
        Card(label: "Resting heart rate", accent: AppColor.recovery,
             accessory: .delta(DeltaInfo(value: 54, baseline: 56), upIsGood: false)) {
            Sparkline(samples: mock.restingHRSeries(days: 14), color: AppColor.recovery)
        }
        .navigates(to: .heartRate)
    }

    private var bodyTempCard: some View {
        Card(label: "Skin temperature", accent: AppColor.recovery, accessory: .value("−0.2 °C")) {
            Sparkline(samples: mock.series(days: 14, base: 0, spread: 0.8), color: AppColor.recovery)
        }
        .navigates(to: .bodyTemp)
    }

    private var respiratoryCard: some View {
        Card(label: "Respiratory rate", accent: AppColor.recovery, accessory: .value("14.1")) {
            Sparkline(samples: mock.series(days: 14, base: 14, spread: 2), color: AppColor.recovery)
        }
        .navigates(to: .respiratory)
    }

    private var trendsCard: some View {
        Card(label: "Recovery trends") {
            VStack(spacing: Spacing.sm) {
                PeriodPicker(period: $period)
                LineTrendChart(samples: mock.series(days: period.days, base: 70, spread: 24),
                               color: AppColor.recovery, baseline: nil)
                    .animation(.snappy, value: period)
            }
        }
    }
}

#Preview {
    NavigationStack { RecoveryView() }
}
