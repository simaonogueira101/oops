import SwiftUI

/// The Overview tab: the metric rings with flanking stats, then Apple-Health-style cards.
struct OverviewView: View {
    let metrics: DayMetrics
    let battery: BatteryStatus?
    let lastSync: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ringSection
                cards
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private var ringSection: some View {
        HStack(alignment: .center) {
            stat(value: "\(percent(metrics.recovery))%", title: "RECOVERY", sub: "\(metrics.hrv) HRV",
                 color: .green, alignment: .leading)
            Spacer(minLength: 0)
            MetricRings(recovery: metrics.recovery, strain: metrics.strainFraction, size: 150)
            Spacer(minLength: 0)
            stat(value: metrics.strain.formatted(.number.precision(.fractionLength(1))), title: "STRAIN",
                 sub: "\(percent(metrics.sleepPerformance))% SLEEP", color: .blue, alignment: .trailing)
        }
        .padding(.vertical, Spacing.sm)
    }

    private func percent(_ fraction: Double) -> Int { Int((fraction * 100).rounded()) }

    private func stat(value: String, title: String, sub: String, color: Color,
                      alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Spacing.xxs) {
            Text(value).font(.title.weight(.semibold)).foregroundStyle(color)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(sub).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var cards: some View {
        VStack(spacing: Spacing.md) {
            SummaryCard(title: "Ring Battery", systemImage: "circle.dashed", tint: .green) {
                if let battery {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                        Text("\(battery.level)").font(.largeTitle.weight(.semibold)).monospacedDigit()
                        Text("%").font(.title3).foregroundStyle(.secondary)
                        Spacer()
                        if battery.isCharging {
                            Label("Charging", systemImage: "bolt.fill").font(.subheadline).foregroundStyle(.green)
                        }
                    }
                } else {
                    Text("No reading yet").foregroundStyle(.secondary)
                }
            }

            SummaryCard(title: "Mac Sync", systemImage: "laptopcomputer", tint: .blue) {
                Text(lastSync.map { "Synced \($0.formatted(.relative(presentation: .named)))" } ?? "Not synced yet")
                    .foregroundStyle(.secondary)
            }

            SummaryCard(title: "Sleep", systemImage: "bed.double.fill", tint: .indigo) {
                Text("No data yet — arrives with the ring.").foregroundStyle(.secondary)
            }
        }
    }
}

/// A rounded Apple-Health-style summary card.
struct SummaryCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
