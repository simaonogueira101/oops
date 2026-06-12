import SwiftUI

/// The Overview "Today" tab: a scrollable feed of cards. Each card deep-links into its domain
/// tab or a detail screen. Shared by iPhone and the Mac companion.
struct OverviewView: View {
    let metrics: DayMetrics
    @Binding var date: Date

    private var mock: MockHealthData { MockHealthData() }
    private var sleepScore: Int { Int((metrics.sleepPerformance * 100).rounded()) }
    private var recoveryBand: ScoreBand { ScoreBand(score: metrics.score) }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // iOS shows the day in the persistent TopBar; the Mac companion has no top bar,
                // so it gets the in-content date scroller instead.
                #if os(macOS)
                DateScroller(date: $date)
                #endif
                recoveryHero
                sleepStrainRow
                stepsCard
                heartRateCard
                stressSpo2Row
                tempRespiratoryRow
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
    }

    // MARK: Hero

    private var recoveryHero: some View {
        Card(label: "Recovery", title: recoveryBand.label, accent: AppColor.recovery, accessory: .chevron) {
            CompositeHeroRing(
                score: metrics.score, accent: AppColor.recovery,
                leading: [HeroStat(value: "\(metrics.hrv)", label: "HRV", color: AppColor.recovery),
                          HeroStat(value: "\(metrics.restingHR)", label: "RHR", color: AppColor.recovery)],
                trailing: [HeroStat(value: strainText, label: "Strain", color: AppColor.strain),
                           HeroStat(value: "\(sleepScore)", label: "Sleep", color: AppColor.sleep)]
            )
            .padding(.vertical, Spacing.xs)
        }
        .navigates(to: .recovery)
    }

    // MARK: Rows

    private var sleepStrainRow: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Card(label: "Sleep", accent: AppColor.sleep, accessory: .chevron) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    compactValue("\(sleepScore)", color: AppColor.sleep)
                    Sparkline(samples: mock.hrvSeries(days: 10), color: AppColor.sleep)
                }
            }
            .navigates(to: .sleep)

            Card(label: "Strain", accent: AppColor.strain, accessory: .chevron) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    compactValue(strainText, color: AppColor.strain)
                    Sparkline(samples: mock.stepsSeries(days: 10), color: AppColor.strain)
                }
            }
            .navigates(to: .strain)
        }
    }

    private var stepsCard: some View {
        Card(label: "Steps", accent: AppColor.strain, accessory: .chevron) {
            GoalProgress(current: Double(metrics.steps), goal: Double(metrics.stepGoal),
                         accent: AppColor.strain, unit: "steps")
        }
        .navigates(to: .strain)
    }

    private var heartRateCard: some View {
        Card(label: "Heart Rate", accent: AppColor.recovery, accessory: .chevron) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Sparkline(samples: mock.restingHRSeries(days: 14), color: AppColor.recovery)
                Text("Resting \(metrics.restingHR) · now 61 bpm")
                    .font(.footnote).foregroundStyle(AppColor.secondaryLabel)
            }
        }
        .navigates(to: .heartRate)
    }

    private var stressSpo2Row: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Card(label: "Stress", accent: AppColor.strain, accessory: .chevron) {
                compactValue("\(metrics.stress)", color: AppColor.strain)
            }
            .navigates(to: .stress)
            Card(label: "Blood O₂", accent: AppColor.recovery, accessory: .chevron) {
                compactValue("\(metrics.spo2)", unit: "%", color: AppColor.recovery)
            }
            .navigates(to: .spo2)
        }
    }

    private var tempRespiratoryRow: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Card(label: "Skin Temp", accent: AppColor.recovery, accessory: .chevron) {
                compactValue(metrics.bodyTempDelta.formatted(.number.precision(.fractionLength(1))),
                             unit: "°C", color: AppColor.recovery)
            }
            .navigates(to: .bodyTemp)
            Card(label: "Respiratory", accent: AppColor.recovery, accessory: .chevron) {
                compactValue(metrics.respiratoryRate.formatted(.number.precision(.fractionLength(1))),
                             color: AppColor.recovery)
            }
            .navigates(to: .respiratory)
        }
    }

    // MARK: Helpers

    private var strainText: String { metrics.strain.formatted(.number.precision(.fractionLength(1))) }

    private func compactValue(_ text: String, unit: String? = nil, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
            Text(text).font(.title.weight(.semibold)).foregroundStyle(color)
            if let unit {
                Text(unit).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
            }
        }
    }
}

#Preview {
    NavigationStack {
        OverviewView(metrics: .sample, date: .constant(.now))
            .appNavigationDestinations()
    }
}
