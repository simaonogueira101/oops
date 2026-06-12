import SwiftUI

/// The Sleep tab: score, the staggered-stage hypnogram, stage breakdown, contributors, and the
/// supporting overnight metrics — all composed from `Card`.
struct SleepView: View {
    @State private var period: Period = .week
    private var mock: MockHealthData { MockHealthData() }
    private var session: SleepSession { mock.sleepSession() }
    private let order: [SleepStage] = [.awake, .rem, .light, .deep]

    var body: some View {
        if session.intervals.isEmpty {
            ContentUnavailableView("No Sleep Data", systemImage: "moon.zzz",
                                   description: Text("Wear your ring to bed to track sleep."))
        } else {
            content
        }
    }

    private var content: some View {
        TopScrollView {
            VStack(spacing: Spacing.md) {
                PageHeader(title: "Sleep")
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
    }

    private var scoreHero: some View {
        Card(label: "Sleep", accent: AppColor.sleep) {
            HStack(spacing: Spacing.lg) {
                ScoreRing(score: 86, accent: AppColor.sleep, caption: ScoreBand(score: 86).label, size: 120)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(session.totalAsleep.formattedDuration).font(.title.weight(.semibold))
                    Text("asleep").font(.caption).foregroundStyle(AppColor.secondaryLabel)
                }
            }
        }
    }

    private var hypnogramCard: some View {
        Card(label: "Sleep stages") {
            SleepStageChart(session: session)
                .accessibilityLabel("Chart of sleep stages across the night")
        }
    }

    private var breakdownCard: some View {
        Card(label: "Time in each stage") {
            GeometryReader { geo in
                VStack(spacing: Spacing.sm) {
                    ForEach(order) { stage in
                        stageRow(stage, fullWidth: geo.size.width)
                    }
                }
            }
            .frame(height: CGFloat(order.count) * 26 + CGFloat(order.count - 1) * Spacing.sm)
        }
    }

    /// One proportional bar (width ∝ the stage's share of the night) followed by its name,
    /// duration, and percentage — Apple Health's stage legend.
    private func stageRow(_ stage: SleepStage, fullWidth: CGFloat) -> some View {
        let maxDuration = order.map { session.duration(of: $0) }.max() ?? 1
        let fraction = maxDuration > 0 ? session.duration(of: stage) / maxDuration : 0
        let width = max(26, fullWidth * 0.55 * fraction)
        return HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(stage.color)
                .frame(width: width, height: 22)
            Text(stage.title).font(.subheadline.weight(.semibold))
            Text(session.duration(of: stage).formattedDuration)
                .font(.caption).foregroundStyle(AppColor.secondaryLabel).monospacedDigit()
            if stage != .awake {
                Text("\(session.percentage(of: stage))%")
                    .font(.caption).foregroundStyle(.tertiary).monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .frame(height: 26)
        .accessibilityElement(children: .combine)
    }

    private var contributorsCard: some View {
        Card(label: "Contributors") {
            ContributorRows(tint: AppColor.sleep, contributors: [
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
                           color: AppColor.sleep, baseline: 54)
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
                BarSeriesChart(samples: mock.series(days: period.days, base: 86, spread: 16), color: AppColor.sleep)
                    .animation(.snappy, value: period)
            }
        }
    }

    // MARK: Helpers

    private func timeText(_ date: Date?) -> String {
        date?.formatted(.dateTime.hour().minute()) ?? "–"
    }
}

#Preview {
    NavigationStack { SleepView() }
}
