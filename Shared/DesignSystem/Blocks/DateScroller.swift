import SwiftUI

/// A prev / current-day / next header that steps the selected date; forward is disabled on today.
struct DateScroller: View {
    @Binding var date: Date

    private var cal: Calendar { .current }
    private var isToday: Bool { cal.isDateInToday(date) }

    var body: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.backward").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Previous day")
            Spacer()
            VStack(spacing: 0) {
                Text(isToday ? "Today" : date.formatted(.dateTime.weekday(.wide)))
                    .font(.headline)
                Text(date.formatted(.dateTime.day().month()))
                    .font(.caption).foregroundStyle(AppColor.secondaryLabel)
            }
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.forward").frame(minWidth: 44, minHeight: 44) }.disabled(isToday).accessibilityLabel("Next day")
        }
        .tint(AppColor.accent)
        .sensoryFeedback(.selection, trigger: date)
    }

    private func shift(_ days: Int) {
        if let next = cal.date(byAdding: .day, value: days, to: date) { date = next }
    }
}

#Preview {
    DateScroller(date: .constant(.now)).padding()
}
