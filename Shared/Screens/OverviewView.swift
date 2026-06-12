import SwiftUI

/// One day's "Summary" feed: a header (title + date), the recovery hero, and the sleep & strain
/// cards. Day paging is handled by the enclosing `SummaryPager` (iOS); shared with macOS.
struct OverviewView: View {
    let metrics: DayMetrics
    var date: Date = .now
    let recorder: WorkoutRecorder
    /// Switches to a domain's tab (Summary cards never duplicate a tab inside a sheet).
    var openDomain: (Domain) -> Void = { _ in }

    private var mock: MockHealthData { MockHealthData() }
    private var sleepScore: Int { Int((metrics.sleepPerformance * 100).rounded()) }
    private var recoveryBand: ScoreBand { ScoreBand(score: metrics.score) }
    private var strainText: String { metrics.strain.formatted(.number.precision(.fractionLength(1))) }

    var body: some View {
        TopScrollView {
            VStack(spacing: Spacing.md) {
                PageHeader(title: "Summary")
                #if os(macOS)
                ActiveWorkoutBanner(recorder: recorder)
                #endif
                recoveryHero
                sleepCard
                strainCard
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
    }

    // MARK: Hero

    private var recoveryHero: some View {
        Card(label: "Recovery", systemImage: "gauge.with.needle",
             accent: AppColor.recovery, accessory: .chevron) {
            ScoreHero(score: metrics.score, accent: AppColor.recovery, caption: recoveryBand.label, stats: [
                HeroStat(label: "HRV", value: "\(metrics.hrv) ms",
                         symbol: "waveform.path.ecg", color: AppColor.recovery),
                HeroStat(label: "Resting HR", value: "\(metrics.restingHR) bpm",
                         symbol: "heart.fill", color: AppColor.recovery),
                HeroStat(label: "Strain", value: strainText,
                         symbol: "flame.fill", color: AppColor.strain),
                HeroStat(label: "Sleep", value: "\(sleepScore)",
                         symbol: "bed.double.fill", color: AppColor.sleep)
            ])
            .padding(.vertical, Spacing.xs)
        }
        .domainButton(.recovery, openDomain)
    }

    // MARK: Cards

    private var sleepCard: some View {
        Card(label: "Sleep", systemImage: "bed.double.fill", accent: AppColor.sleep, accessory: .chevron) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                compactValue("\(sleepScore)")
                Sparkline(samples: mock.sleepScoreSeries(days: 14), color: AppColor.sleep)
            }
        }
        .domainButton(.sleep, openDomain)
    }

    private var strainCard: some View {
        Card(label: "Strain", systemImage: "flame.fill", accent: AppColor.strain, accessory: .chevron) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                compactValue(strainText)
                Sparkline(samples: mock.strainSeries(days: 14), color: AppColor.strain)
            }
        }
        .domainButton(.strain, openDomain)
    }

    private func compactValue(_ text: String) -> some View {
        Text(text).font(.cardValue).foregroundStyle(AppColor.label).monospacedDigit()
    }
}

private extension View {
    /// Wraps a card so tapping it switches to the given domain tab.
    func domainButton(_ domain: Domain, _ open: @escaping (Domain) -> Void) -> some View {
        Button { open(domain) } label: { self }
            .buttonStyle(CardLinkStyle())
    }
}

#Preview {
    OverviewView(metrics: .sample, date: .now, recorder: WorkoutRecorder())
        .background(AppColor.background)
}
