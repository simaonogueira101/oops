import SwiftUI

/// Summary as a full-view horizontal pager: swipe between days (a window ending today), like a
/// paged dot-indicator menu. The selected day drives `date` (and every page header).
struct SummaryPager: View {
    @Binding var date: Date
    let recorder: WorkoutRecorder
    let openDomain: (Domain) -> Void

    /// Last 14 days, oldest → today (today is the last page, so you can't swipe past it).
    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<14).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        TabView(selection: $date) {
            ForEach(days, id: \.self) { day in
                OverviewView(metrics: .sample, date: day, recorder: recorder, openDomain: openDomain)
                    .tag(day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .sensoryFeedback(.selection, trigger: date)
    }
}
