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
                ForEach(zones) { zone in
                    Card(label: zone.name, accessory: .value("\(zone.minutes)m")) {
                        HStack(spacing: Spacing.sm) {
                            RoundedRectangle(cornerRadius: 3).fill(zone.color).frame(width: 10, height: 10)
                            Text("\(zone.lowerBPM)–\(zone.upperBPM) bpm")
                                .font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
                            Spacer()
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .inlineNavigationTitle("Zones")
    }
}

#Preview {
    NavigationStack { HRZonesView() }
}
