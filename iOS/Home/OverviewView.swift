import SwiftUI

/// The Overview tab: two concentric rings flanked by four equally-sized stats —
/// recovery + HRV (green) on the left, strain + sleep (blue) on the right.
struct OverviewView: View {
    let metrics: DayMetrics

    var body: some View {
        VStack {
            Spacer()
            ringSection
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ringSection: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(spacing: Spacing.lg) {
                stat("\(percent(metrics.recovery))%", "RECOVERY", .green)
                stat("\(metrics.hrv)", "HRV", .green)
            }
            MetricRings(recovery: metrics.recovery, strain: metrics.strainFraction, size: 160)
            VStack(spacing: Spacing.lg) {
                stat(metrics.strain.formatted(.number.precision(.fractionLength(1))), "STRAIN", .blue)
                stat("\(percent(metrics.sleepPerformance))%", "SLEEP", .blue)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(value).font(.title2.weight(.semibold)).foregroundStyle(color)
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func percent(_ fraction: Double) -> Int { Int((fraction * 100).rounded()) }
}
