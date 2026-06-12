import SwiftUI

/// Heart-rate zones: a labelled row per zone plus a proportional time-in-zone bar — segment
/// widths encode minutes spent (the bar carries data, not decoration).
struct ZoneScale: View {
    var zones: [HRZone]

    private var totalMinutes: Int { max(1, zones.reduce(0) { $0 + $1.minutes }) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(zones) { zone in
                HStack(spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: 3).fill(zone.color).frame(width: 10, height: 10)
                    Text(zone.name).font(.subheadline)
                    Spacer()
                    Text("\(zone.lowerBPM)–\(zone.upperBPM) bpm")
                        .font(.caption).foregroundStyle(AppColor.secondaryLabel)
                    Text((TimeInterval(zone.minutes) * 60).formattedDuration)
                        .font(.caption.weight(.semibold)).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
            GeometryReader { geo in
                HStack(spacing: Spacing.xxs / 2) {
                    ForEach(zones) { zone in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(zone.color)
                            .frame(width: max(4, (geo.size.width - CGFloat(zones.count - 1) * Spacing.xxs / 2)
                                                 * CGFloat(zone.minutes) / CGFloat(totalMinutes)))
                    }
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    ZoneScale(zones: MockHealthData().hrZones()).padding().background(AppColor.background)
}
