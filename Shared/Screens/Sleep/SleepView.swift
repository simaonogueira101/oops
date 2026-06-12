import SwiftUI

/// The Sleep tab: score, the staggered-stage hypnogram, stage breakdown, contributors, and the
/// supporting overnight metrics — all composed from `Card`.
struct SleepView: View {
    @State private var period: Period = .week
    private var mock: MockHealthData { MockHealthData() }
    private var session: SleepSession { mock.sleepSession() }
    private let order: [SleepStage] = [.awake, .rem, .light, .deep]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                scoreHero
                hypnogramCard
                breakdownCard
                contributorsCard
                sleepingHRCard
                timingCard
                trendsCard
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .inlineNavigationTitle("Sleep")
    }

    private var scoreHero: some View {
        Card(label: "Sleep", title: "Restful night", accent: AppColor.sleep,
             footer: .text("REM and deep sleep accounted for a healthy share of your night.")) {
            HStack(spacing: Spacing.lg) {
                ScoreRing(score: 86, accent: AppColor.sleep, caption: "Good", size: 120)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(hm(session.totalAsleep)).font(.title.weight(.semibold))
                    Text("asleep").font(.caption).foregroundStyle(AppColor.secondaryLabel)
                }
            }
        }
    }

    private var hypnogramCard: some View {
        Card(label: "Sleep stages") {
            SleepStageChart(session: session)
        }
    }

    private var breakdownCard: some View {
        Card(label: "Time in each stage") {
            VStack(spacing: Spacing.sm) {
                ForEach(order) { stage in
                    HStack(spacing: Spacing.sm) {
                        RoundedRectangle(cornerRadius: 3).fill(stage.color).frame(width: 10, height: 10)
                        Text(stage.title).font(.subheadline)
                        Spacer()
                        if stage != .awake {
                            Text("\(session.percentage(of: stage))%")
                                .font(.caption.weight(.semibold)).foregroundStyle(AppColor.secondaryLabel)
                        }
                        Text(hm(session.duration(of: stage))).font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                }
            }
        }
    }

    private var contributorsCard: some View {
        Card(label: "Contributors") {
            ContributorRows(contributors: [
                Contributor(name: "Total sleep", fraction: 0.86, band: .optimal),
                Contributor(name: "Efficiency", fraction: 0.92, band: .optimal),
                Contributor(name: "Restfulness", fraction: 0.6, band: .good),
                Contributor(name: "Latency", fraction: 0.7, band: .good),
                Contributor(name: "Timing", fraction: 0.45, band: .poor)
            ])
        }
    }

    private var sleepingHRCard: some View {
        Card(label: "Sleeping heart rate", accessory: .value("52 bpm")) {
            LineTrendChart(samples: mock.series(days: 14, base: 52, spread: 8),
                           color: AppColor.recovery, baseline: 54)
        }
    }

    private var timingCard: some View {
        Card(label: "Timing") {
            HStack {
                StatTile(label: "Bedtime", value: timeText(session.start))
                StatTile(label: "Wake", value: timeText(session.end))
            }
        }
    }

    private var trendsCard: some View {
        Card(label: "Sleep trends") {
            VStack(spacing: Spacing.sm) {
                PeriodPicker(period: $period)
                BarSeriesChart(samples: mock.series(days: 14, base: 86, spread: 16), color: AppColor.sleep)
            }
        }
    }

    // MARK: Helpers

    private func hm(_ ti: TimeInterval) -> String {
        let minutes = Int(ti / 60)
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    private func timeText(_ date: Date?) -> String {
        date?.formatted(.dateTime.hour().minute()) ?? "–"
    }
}

#Preview {
    NavigationStack { SleepView() }
}
