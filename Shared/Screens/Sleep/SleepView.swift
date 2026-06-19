import SwiftUI

/// The Sleep tab: score, the staggered-stage hypnogram, stage breakdown, contributors, and the
/// supporting overnight metrics — all composed from `Card`.
struct SleepView: View {
    var date: Date = .now
    @State private var period: Period = .today
    @Environment(\.healthData) private var health
    private var session: SleepSession { health.sleepSession(for: date) }
    private var metrics: DayMetrics { health.dayMetrics(for: date) }
    private var sleepScore: Int { Int((metrics.sleepPerformance * 100).rounded()) }
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
                ScoreRing(score: sleepScore, accent: AppColor.sleep, caption: ScoreBand(score: sleepScore).label, size: 120)
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
            ZoneScale(segments: order.map { stage in
                ZoneSegment(
                    name: stage.title,
                    detail: stage == .awake ? nil : "\(session.percentage(of: stage))%",
                    minutes: Int(session.duration(of: stage) / 60),
                    color: stage.color
                )
            })
        }
    }

    private var contributorsCard: some View {
        Card(label: "Contributors") {
            ContributorRows(tint: AppColor.sleep, contributors: [
                Contributor(name: "Total sleep", fraction: nil, band: nil),
                Contributor(name: "Efficiency", fraction: nil, band: nil),
                Contributor(name: "Restfulness", fraction: nil, band: nil),
                Contributor(name: "Latency", fraction: nil, band: nil),
                Contributor(name: "Timing", fraction: nil, band: nil)
            ])
        }
    }

    private var sleepingHRCard: some View {
        Card(label: "Sleeping heart rate",
             accessory: .value(metrics.restingHR.map { "\($0) bpm" } ?? "—")) {
            BarSeriesChart(samples: health.restingHRSeries(days: 7), period: .week,
                           color: AppColor.sleep, baseline: nil)
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
                BarSeriesChart(samples: health.sleepScoreSeries(days: period.days),
                               period: period, color: AppColor.sleep, baseline: nil)
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
