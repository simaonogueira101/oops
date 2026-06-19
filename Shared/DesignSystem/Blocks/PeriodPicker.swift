import SwiftUI

/// Time window for trends and detail screens.
enum Period: String, CaseIterable, Identifiable {
    case today = "Today", week = "Week", month = "Month", year = "Year"
    var id: String { rawValue }

    /// Days of data the window covers — every chart derives its series from this.
    var days: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }

    /// True when the window is a single day, rendered hour-by-hour instead of day-by-day.
    var isIntraday: Bool { self == .today }

    /// The full window the period covers, so a chart's X axis can span the whole range
    /// even where there is no data (e.g. a year shows all twelve months).
    func dateRange(relativeTo now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date> {
        switch self {
        case .today:
            return calendar.startOfDay(for: now)...now
        default:
            let start = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: -(days - 1), to: now) ?? now)
            return start...now
        }
    }

    /// Axis tick cadence: hourly for today, daily for a week, ~weekly for a month, monthly for a year.
    var axisStride: (component: Calendar.Component, count: Int) {
        switch self {
        case .today: return (.hour, 6)
        case .week: return (.day, 1)
        case .month: return (.day, 7)
        case .year: return (.month, 1)
        }
    }

    /// Bar bucketing unit: hours intraday, days otherwise.
    var barUnit: Calendar.Component { isIntraday ? .hour : .day }
}

/// A segmented Day/Week/Month/Year picker.
struct PeriodPicker: View {
    @Binding var period: Period

    var body: some View {
        Picker("Period", selection: $period) {
            ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    PeriodPicker(period: .constant(.week)).padding()
}
