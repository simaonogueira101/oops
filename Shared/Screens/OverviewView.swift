import SwiftUI

/// The Overview "Today" tab: a scrollable feed of cards. Each card deep-links into its domain
/// tab or a detail screen. Shared by iPhone and the Mac companion.
struct OverviewView: View {
    let metrics: DayMetrics
    @Binding var date: Date
    let recorder: WorkoutRecorder
    /// Switches to a domain's tab (Summary cards never duplicate a tab inside a sheet).
    var openDomain: (Domain) -> Void = { _ in }

    @State private var swipeEdge: Edge = .trailing
    private var mock: MockHealthData { MockHealthData() }
    private var sleepScore: Int { Int((metrics.sleepPerformance * 100).rounded()) }
    private var recoveryBand: ScoreBand { ScoreBand(score: metrics.score) }
    private var dayKey: Date { Calendar.current.startOfDay(for: date) }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // iOS shows the day in the persistent TopBar; the Mac companion has no top bar,
                // so it gets the in-content date scroller instead.
                #if os(macOS)
                DateScroller(date: $date)
                ActiveWorkoutBanner(recorder: recorder)
                #endif
                recoveryHero
                sleepCard
                strainCard
                stepsCard
                heartRateCard
            }
            .padding(Spacing.md)
            .id(dayKey)
            .transition(.push(from: swipeEdge))
        }
        .background(AppColor.background)
        .navigationTitle("Summary")
        .simultaneousGesture(daySwipe)
        .sensoryFeedback(.selection, trigger: dayKey)
    }

    /// Horizontal swipe pages between days (left = forward, capped at today) with a visible
    /// push transition; vertical drags still scroll the feed.
    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) * 1.5, abs(dx) > 48 else { return }
                let cal = Calendar.current
                if dx < 0 {
                    guard !cal.isDateInToday(date),
                          let next = cal.date(byAdding: .day, value: 1, to: date) else { return }
                    swipeEdge = .trailing
                    withAnimation(.snappy) { date = next }
                } else if let previous = cal.date(byAdding: .day, value: -1, to: date) {
                    swipeEdge = .leading
                    withAnimation(.snappy) { date = previous }
                }
            }
    }

    // MARK: Hero

    private var recoveryHero: some View {
        Card(label: "Recovery", systemImage: "gauge.with.needle", title: recoveryBand.label,
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

    private var stepsCard: some View {
        Card(label: "Steps", systemImage: "figure.walk", accent: AppColor.strain, accessory: .chevron) {
            GoalProgress(current: Double(metrics.steps), goal: Double(metrics.stepGoal),
                         accent: AppColor.strain, unit: "steps")
        }
        .domainButton(.strain, openDomain)
    }

    private var heartRateCard: some View {
        Card(label: "Heart Rate", systemImage: "heart.fill", accent: AppColor.recovery, accessory: .chevron) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Sparkline(samples: mock.restingHRSeries(days: 14), color: AppColor.recovery)
                Text("Resting \(metrics.restingHR) · now \(metrics.currentHR) bpm")
                    .font(.footnote).foregroundStyle(AppColor.secondaryLabel)
            }
        }
        .navigates(to: .heartRate)
    }

    // MARK: Helpers

    private var strainText: String { metrics.strain.formatted(.number.precision(.fractionLength(1))) }

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
    let recorder = WorkoutRecorder()
    let _ = recorder.start(.run)
    return NavigationStack {
        OverviewView(metrics: .sample, date: .constant(.now), recorder: recorder)
    }
}
