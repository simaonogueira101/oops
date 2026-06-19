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
