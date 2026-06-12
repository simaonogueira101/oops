import SwiftUI

/// One segment of a `ZoneScale` (an HR zone, a sleep stage, …).
struct ZoneSegment: Identifiable {
    let id = UUID()
    let name: String
    /// Optional secondary detail shown before the duration (a bpm range, a percentage, …).
    let detail: String?
    let minutes: Int
    let color: Color
}

/// Labelled rows plus a proportional time bar — segment widths encode minutes spent (the bar
/// carries data, not decoration). Shared by HR zones and the sleep-stage breakdown.
struct ZoneScale: View {
    var segments: [ZoneSegment]

    private var totalMinutes: Int { max(1, segments.reduce(0) { $0 + $1.minutes }) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(segments) { segment in
                HStack(spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: 3).fill(segment.color).frame(width: 10, height: 10)
                    Text(segment.name).font(.subheadline)
                    Spacer()
                    if let detail = segment.detail {
                        Text(detail)
                            .font(.caption).foregroundStyle(AppColor.secondaryLabel).monospacedDigit()
                    }
                    Text((TimeInterval(segment.minutes) * 60).formattedDuration)
                        .font(.caption.weight(.semibold)).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
            GeometryReader { geo in
                HStack(spacing: Spacing.xxs / 2) {
                    ForEach(segments) { segment in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(segment.color)
                            .frame(width: max(4, (geo.size.width - CGFloat(segments.count - 1) * Spacing.xxs / 2)
                                                 * CGFloat(segment.minutes) / CGFloat(totalMinutes)))
                    }
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
    }
}

extension ZoneScale {
    /// Convenience for heart-rate zones (detail = the bpm range).
    init(zones: [HRZone]) {
        self.init(segments: zones.map { zone in
            ZoneSegment(name: zone.name, detail: "\(zone.lowerBPM)–\(zone.upperBPM) bpm",
                        minutes: zone.minutes, color: zone.color)
        })
    }
}

#Preview {
    ZoneScale(zones: MockHealthData().hrZones()).padding().background(AppColor.background)
}
