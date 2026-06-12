import SwiftUI
import Charts

/// Apple-Health-style stacked-area hypnogram: each interval is a column built from horizontal
/// stage bands (navy Deep at the bottom up to the current stage), so the top edge follows the
/// night — white-capped Awake peaks, light-blue REM, medium-blue Light, short navy Deep.
struct SleepStageChart: View {
    var session: SleepSession
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 200

    var body: some View {
        Chart {
            ForEach(session.intervals) { interval in
                ForEach(0..<interval.stage.stackHeight, id: \.self) { level in
                    RectangleMark(
                        xStart: .value("Start", interval.start),
                        xEnd: .value("End", interval.end),
                        yStart: .value("Low", level),
                        yEnd: .value("High", level + 1)
                    )
                    .foregroundStyle(SleepStage.bandColor(level))
                }
            }
        }
        .chartYScale(domain: 0...4)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) {
                AxisValueLabel(format: .dateTime.hour())
                    .foregroundStyle(AppColor.secondaryLabel)
            }
        }
        .modifier(SleepXDomain(start: session.start, end: session.end))
        .frame(height: chartHeight)
        .overlay(alignment: .bottomLeading) { timePill(session.start) }
        .overlay(alignment: .bottomTrailing) { timePill(session.end) }
    }

    @ViewBuilder private func timePill(_ date: Date?) -> some View {
        if let date {
            Text(date.formatted(.dateTime.hour().minute()))
                .font(.caption2).monospacedDigit()
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs / 2)
                .background(AppColor.track, in: Capsule())
        }
    }
}

/// Pins the x-axis to the exact night (no auto-padding past bedtime/wake).
private struct SleepXDomain: ViewModifier {
    var start: Date?
    var end: Date?
    func body(content: Content) -> some View {
        if let start, let end, start < end {
            content.chartXScale(domain: start...end)
        } else {
            content
        }
    }
}

#Preview {
    SleepStageChart(session: MockHealthData().sleepSession())
        .padding()
        .background(AppColor.background)
}
