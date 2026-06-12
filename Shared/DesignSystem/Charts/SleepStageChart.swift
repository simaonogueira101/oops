import SwiftUI
import Charts

/// Staggered horizontal hypnogram: each contiguous stage interval is a rounded bar at its stage's
/// row (Awake on top → Deep at the bottom), so segments stagger across rows over the night.
struct SleepStageChart: View {
    var session: SleepSession
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 160

    /// Top-to-bottom display order.
    private let order: [SleepStage] = [.awake, .rem, .light, .deep]

    var body: some View {
        Chart(session.intervals) { interval in
            BarMark(
                xStart: .value("Start", interval.start),
                xEnd: .value("End", interval.end),
                y: .value("Stage", interval.stage.title)
            )
            .cornerRadius(4)
            .foregroundStyle(interval.stage.color)
        }
        // Swift Charts places the first categorical value at the top, so pass order as-is
        // (Awake → Deep) to get the conventional Awake-on-top hypnogram.
        .chartYScale(domain: order.map(\.title))
        .chartYAxis {
            AxisMarks(position: .leading, values: order.map(\.title)) { value in
                AxisValueLabel {
                    if let title = value.as(String.self) { Text(title).font(.caption2) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .modifier(SleepXDomain(start: session.start, end: session.end))
        .frame(height: chartHeight)
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
