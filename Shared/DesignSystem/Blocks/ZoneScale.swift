import SwiftUI

/// Heart-rate (or stress) zones: a labelled row per zone plus a gradient legend bar.
struct ZoneScale: View {
    var zones: [HRZone]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(zones) { zone in
                HStack(spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: 3).fill(zone.color).frame(width: 10, height: 10)
                    Text(zone.name).font(.subheadline)
                    Spacer()
                    Text("\(zone.lowerBPM)–\(zone.upperBPM) bpm")
                        .font(.caption).foregroundStyle(AppColor.secondaryLabel)
                    Text("\(zone.minutes)m").font(.caption.weight(.semibold)).monospacedDigit()
                }
            }
            LinearGradient(colors: zones.map(\.color), startPoint: .leading, endPoint: .trailing)
                .frame(height: 8)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    ZoneScale(zones: MockHealthData().hrZones()).padding().background(AppColor.background)
}
