import SwiftUI
import Charts

/// Two concentric progress rings drawn with Swift Charts (SectorMark donuts), styled like
/// Apple's Activity / Health rings: recovery (outer) and strain (inner).
struct MetricRings: View {
    let recovery: Double   // 0...1
    let strain: Double     // 0...1
    var size: CGFloat = 190

    var body: some View {
        ZStack {
            ring(value: recovery, color: .green)
            ring(value: strain, color: .blue)
                .scaleEffect(0.72)
            Image(systemName: "circle.dashed")
                .font(.title)
                .foregroundStyle(.tertiary)
        }
        .frame(width: size, height: size)
    }

    private func ring(value: Double, color: Color) -> some View {
        Chart {
            SectorMark(
                angle: .value("Value", max(value, 0.0001)),
                innerRadius: .ratio(0.82),
                angularInset: 1.5
            )
            .cornerRadius(6)
            .foregroundStyle(color)

            SectorMark(
                angle: .value("Track", max(1 - value, 0.0001)),
                innerRadius: .ratio(0.82)
            )
            .foregroundStyle(color.opacity(0.15))
        }
        .chartLegend(.hidden)
    }
}
