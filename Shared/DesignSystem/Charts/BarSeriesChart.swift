import SwiftUI
import Charts

/// A daily/hourly bar trend whose X axis always spans the full selected period — bars appear
/// only where data exists, gaps stay empty. Optional dashed baseline and Health-style scrubbing.
struct BarSeriesChart: View {
    var samples: [MetricSample]
    var period: Period
    var color: Color
    var baseline: Double?
    /// Fixed domain override (e.g. a single workout's start…end) — when set, `period` only
    /// drives the bar bucketing unit, not the axis range.
    var xDomain: ClosedRange<Date>?
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 160
    @State private var selection: Date?

    private var domain: ClosedRange<Date> { xDomain ?? period.dateRange() }

    private var selected: MetricSample? {
        guard let selection else { return nil }
        return samples.min {
            abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection))
        }
    }

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                BarMark(x: .value("Date", sample.date, unit: period.barUnit),
                        y: .value("Value", sample.value))
                    .cornerRadius(4)
                    .foregroundStyle(color)
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
            }
        }
        .chartXSelection(value: $selection)
        .chartXScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: .stride(by: period.axisStride.component,
                                      count: period.axisStride.count)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: axisFormat)
            }
        }
        .frame(height: chartHeight)
    }

    private var axisFormat: Date.FormatStyle {
        switch period {
        case .today: return .dateTime.hour()
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day()
        case .year: return .dateTime.month()
        }
    }
}

#Preview {
    BarSeriesChart(samples: MockHealthData().stepsSeries(days: 7), period: .week,
                   color: AppColor.strain, baseline: nil)
        .padding()
        .background(AppColor.background)
}
