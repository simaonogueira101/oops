import SwiftUI

/// Full-view horizontal pager over a window of days (ending today). Swiping changes `date`
/// (synced to the top-bar date control). Used by every main tab so they all page by day.
struct DayPager<Content: View>: View {
    @Binding var date: Date
    @ViewBuilder var content: (Date) -> Content

    /// Last 14 days, oldest → today (today is the last page, so you can't swipe past it).
    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<14).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        TabView(selection: $date) {
            ForEach(days, id: \.self) { day in
                content(day).tag(day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .sensoryFeedback(.selection, trigger: date)
    }
}
