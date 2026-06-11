import SwiftUI
import Charts

/// Staggered horizontal hypnogram: each contiguous stage interval is a rounded bar at its stage's
/// row (Awake on top → Deep at the bottom), so segments stagger across rows over the night.
struct SleepStageChart: View {
    var session: SleepSession

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
        // First domain value sits at the bottom, so reverse to put Awake on top.
        .chartYScale(domain: order.reversed().map(\.title))
        .chartYAxis {
            AxisMarks(position: .leading, values: order.map(\.title)) { value in
                AxisValueLabel {
                    if let title = value.as(String.self) { Text(title).font(.caption2) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) {
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .frame(height: 160)
    }
}

#Preview {
    SleepStageChart(session: MockHealthData().sleepSession())
        .padding()
        .background(AppColor.background)
}
