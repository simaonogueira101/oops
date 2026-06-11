import SwiftUI
import Charts

/// A tiny axis-less line for inline trends inside cards.
struct Sparkline: View {
    var samples: [MetricSample]
    var color: Color

    var body: some View {
        Chart(samples) { sample in
            LineMark(x: .value("t", sample.date), y: .value("v", sample.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 40)
    }
}

#Preview {
    Sparkline(samples: MockHealthData().hrvSeries(days: 14), color: AppColor.recovery).padding()
}
