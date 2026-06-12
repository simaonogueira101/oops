import SwiftUI

/// A single progress ring — `Circle().trim` with round caps (no SectorMark seams), styled like
/// Apple's Activity rings. Reused by `ScoreRing`, `GoalProgress`, and `MetricRings`.
struct RingChart: View {
    var value: Double        // 0...1
    var color: Color
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColor.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(value, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

#Preview {
    RingChart(value: 0.72, color: AppColor.recovery).frame(width: 140, height: 140).padding()
}
