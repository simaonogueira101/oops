import SwiftUI
import Charts

/// A tiny axis-less line for inline trends inside cards.
struct Sparkline: View {
    var samples: [MetricSample]
    var color: Color
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 40

    var body: some View {
        Chart(samples) { sample in
            LineMark(x: .value("t", sample.date), y: .value("v", sample.value))
                .interpolationMethod(.monotone)
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
