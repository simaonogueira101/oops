import SwiftUI
import Charts

/// A line + soft area trend with an optional dashed baseline, an optional fixed time domain,
/// and Health-style scrubbing: touch the chart to read an exact value in a callout.
struct LineTrendChart: View {
    var samples: [MetricSample]
    var color: Color
    var baseline: Double?
    var xDomain: ClosedRange<Date>?
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 180
    @State private var selection: Date?

    private var selected: MetricSample? {
        guard let selection else { return nil }
        return samples.min {
            abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection))
        }
    }

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(x: .value("Date", sample.date), y: .value("Value", sample.value))
                    .interpolationMethod(.linear)
                    .foregroundStyle(color)
                AreaMark(x: .value("Date", sample.date), y: .value("Value", sample.value))
                    .interpolationMethod(.linear)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), .clear],
                                                    startPoint: .top, endPoint: .bottom))
            }
            if let baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(AppColor.secondaryLabel)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(AppColor.separator)
                    .annotation(position: .top,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 0) {
                            Text(Int(selected.value.rounded()).formatted(.number))
                                .font(.headline).monospacedDigit()
                            Text(selected.date, format: .dateTime.day().month())
                                .font(.caption2).foregroundStyle(AppColor.secondaryLabel)
                        }
                        .padding(Spacing.xs)
                        .background(AppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 8))
                    }
                PointMark(x: .value("Selected", selected.date), y: .value("Value", selected.value))
                    .foregroundStyle(color)
            } else if let last = samples.last {
                PointMark(x: .value("Date", last.date), y: .value("Value", last.value))
                    .foregroundStyle(color)
            }
        }
        .chartXSelection(value: $selection)
        .modifier(OptionalXDomain(domain: xDomain))
        .frame(height: chartHeight)
    }
}

private struct OptionalXDomain: ViewModifier {
    var domain: ClosedRange<Date>?
    func body(content: Content) -> some View {
        if let domain {
            content.chartXScale(domain: domain)
        } else {
            content
        }
    }
}

#Preview {
    LineTrendChart(samples: MockHealthData().hrvSeries(days: 14), color: AppColor.recovery, baseline: 44)
        .padding()
        .background(AppColor.background)
}
