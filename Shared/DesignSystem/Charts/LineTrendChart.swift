import SwiftUI
import Charts

/// A line + soft area trend with an optional dashed baseline and a highlighted last point.
struct LineTrendChart: View {
    var samples: [MetricSample]
    var color: Color
    var baseline: Double?

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(x: .value("Date", sample.date), y: .value("Value", sample.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(color)
                AreaMark(x: .value("Date", sample.date), y: .value("Value", sample.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), .clear],
                                                    startPoint: .top, endPoint: .bottom))
            }
            if let baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(AppColor.secondaryLabel)
            }
            if let last = samples.last {
                PointMark(x: .value("Date", last.date), y: .value("Value", last.value))
                    .foregroundStyle(color)
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 180)
    }
}

#Preview {
    LineTrendChart(samples: MockHealthData().hrvSeries(days: 14), color: AppColor.recovery, baseline: 44)
        .padding()
        .background(AppColor.background)
}
