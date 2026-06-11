import SwiftUI

/// Cross-domain trends: a period picker over a stack of metric trend cards, plus links into
/// each domain's own history.
struct TrendsScreen: View {
    @State private var period: Period = .week
    private var mock: MockHealthData { MockHealthData() }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                PeriodPicker(period: $period)
                trendCard("HRV", mock.hrvSeries(days: 14), AppColor.recovery, "48 ms",
                          DeltaInfo(value: 48, baseline: 44), upIsGood: true)
                trendCard("Resting heart rate", mock.restingHRSeries(days: 14), AppColor.recovery, "54 bpm",
                          DeltaInfo(value: 54, baseline: 56), upIsGood: false)
                trendCard("Sleep efficiency", mock.series(days: 14, base: 90, spread: 8), AppColor.sleep, "92%",
                          DeltaInfo(value: 92, baseline: 88), upIsGood: true)
                trendCard("Steps", mock.stepsSeries(days: 14), AppColor.strain, "9,240",
                          DeltaInfo(value: 9240, baseline: 8800), upIsGood: true)
                linksCard
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .inlineNavigationTitle("Trends")
    }

    private func trendCard(_ label: String, _ samples: [MetricSample], _ color: Color,
                           _ value: String, _ delta: DeltaInfo, upIsGood: Bool) -> some View {
        Card(label: label, title: value, accent: color, accessory: .delta(delta, upIsGood: upIsGood)) {
            LineTrendChart(samples: samples, color: color, baseline: nil)
        }
    }

    private var linksCard: some View {
        VStack(spacing: Spacing.sm) {
            link("Sleep", to: .sleep)
            link("Recovery", to: .recovery)
            link("Strain", to: .strain)
        }
    }

    private func link(_ title: String, to route: AppRoute) -> some View {
        Card(label: title, accessory: .chevron) {
            Text("\(title) history").font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
        }
        .navigates(to: route)
    }
}

#Preview {
    NavigationStack { TrendsScreen().appNavigationDestinations() }
}
