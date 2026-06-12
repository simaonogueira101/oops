import SwiftUI

/// Full-view horizontal pager over a window of days (ending today). Implemented as a paging
/// `ScrollView` — NOT a nested `TabView(.page)` — so the bottom tab bar still observes the
/// inner scroll views (transparency + minimize-on-scroll keep working).
struct DayPager<Content: View>: View {
    @Binding var date: Date
    @ViewBuilder var content: (Date) -> Content
    @State private var position: Date?

    /// Last 14 days, oldest → today (today is the last page, so you can't swipe past it).
    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<14).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        content(day)
                            .frame(width: geo.size.width)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
            .scrollIndicators(.hidden)
        }
        .onAppear { position = date }
        .onChange(of: position) { _, new in
            if let new, new != date { date = new }
        }
        .onChange(of: date) { _, new in
            if position != new { withAnimation(.snappy) { position = new } }
        }
        .sensoryFeedback(.selection, trigger: date)
    }
}
