import SwiftUI
import Charts

/// A single progress donut (Swift Charts), styled like Apple's Activity rings. Reused by
/// `ScoreRing`, `GoalProgress`, and `MetricRings`.
struct RingChart: View {
    var value: Double        // 0...1
    var color: Color
    var lineRatio: CGFloat = 0.82

    var body: some View {
        Chart {
            SectorMark(angle: .value("Value", max(value, 0.0001)),
                       innerRadius: .ratio(lineRatio), angularInset: 1.5)
                .cornerRadius(6)
                .foregroundStyle(color)
            SectorMark(angle: .value("Track", max(1 - value, 0.0001)),
                       innerRadius: .ratio(lineRatio))
                .foregroundStyle(AppColor.track)
        }
        .chartLegend(.hidden)
    }
}

#Preview {
    RingChart(value: 0.72, color: AppColor.recovery).frame(width: 140, height: 140).padding()
}
