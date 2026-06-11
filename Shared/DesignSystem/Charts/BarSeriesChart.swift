import SwiftUI
import Charts

/// A simple daily bar series (steps, strain, calories …).
struct BarSeriesChart: View {
    var samples: [MetricSample]
    var color: Color

    var body: some View {
        Chart(samples) { sample in
            BarMark(x: .value("Date", sample.date, unit: .day), y: .value("Value", sample.value))
                .cornerRadius(4)
                .foregroundStyle(color)
        }
        .frame(height: 160)
    }
}

#Preview {
    BarSeriesChart(samples: MockHealthData().stepsSeries(days: 7), color: AppColor.strain)
        .padding()
        .background(AppColor.background)
}
