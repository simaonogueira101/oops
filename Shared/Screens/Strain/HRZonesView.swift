import SwiftUI

/// Heart-rate zones: the gradient scale plus one card per zone (range + time in zone).
struct HRZonesView: View {
    @State private var period: Period = .day
    /// Mock minutes scale with the selected window until real per-period data exists.
    private var zones: [HRZone] {
        MockHealthData().hrZones().map { zone in
            HRZone(name: zone.name, lowerBPM: zone.lowerBPM, upperBPM: zone.upperBPM,
                   minutes: zone.minutes * period.days, color: zone.color)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Card(label: "Time in zones") { ZoneScale(zones: zones) }
            }
            .padding(Spacing.md)
            .animation(.snappy, value: period)
        }
        .safeAreaInset(edge: .top) {
            PeriodPicker(period: $period)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xs)
        }
        .sensoryFeedback(.selection, trigger: period)
        .background(AppColor.background)
        .drawerTitle("Heart Rate Zones")
    }
}

#Preview {
    NavigationStack { HRZonesView() }
}
