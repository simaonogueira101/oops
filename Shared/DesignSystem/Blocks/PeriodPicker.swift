import SwiftUI

/// Time window for trends and detail screens.
enum Period: String, CaseIterable, Identifiable {
    case day = "Day", week = "Week", month = "Month", year = "Year"
    var id: String { rawValue }
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
