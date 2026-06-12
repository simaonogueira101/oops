import SwiftUI

/// Heart-rate zones: the gradient scale plus one card per zone (range + time in zone).
struct HRZonesView: View {
    @State private var period: Period = .day
    private var zones: [HRZone] { MockHealthData().hrZones() }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                PeriodPicker(period: $period)
                Card(label: "Time in zones") { ZoneScale(zones: zones) }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
    }
}

#Preview {
    NavigationStack { HRZonesView() }
}
