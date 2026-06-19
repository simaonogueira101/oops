import SwiftUI
import Charts

/// A tiny axis-less bar series for inline trends inside cards.
struct Sparkline: View {
    var samples: [MetricSample]
    var color: Color
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 40

    var body: some View {
        Chart(samples) { sample in
            BarMark(x: .value("t", sample.date, unit: .day), y: .value("v", sample.value))
                .cornerRadius(2)
                .foregroundStyle(color)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: chartHeight)
    }
}

#Preview {
    Sparkline(samples: MockHealthData().hrvSeries(days: 14), color: AppColor.recovery).padding()
}
