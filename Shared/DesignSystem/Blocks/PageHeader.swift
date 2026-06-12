import SwiftUI

/// A scrolling page header: large title with the selected day beneath it. Shown at the top of
/// every screen (the date indicator the whole app shares).
struct PageHeader: View {
    var title: String
    var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).font(.largeTitle.weight(.bold))
            Text(dateText).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var dateText: String {
        Calendar.current.isDateInToday(date)
            ? "Today"
            : date.formatted(.dateTime.weekday(.wide).month().day())
    }
}

#Preview {
    PageHeader(title: "Summary", date: .now).padding()
}
