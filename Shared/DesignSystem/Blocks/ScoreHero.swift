import SwiftUI

/// A stat row beside the hero ring: tinted symbol for domain identity, secondary label,
/// primary-color value (Apple Fitness Summary idiom — never tinted numbers).
struct HeroStat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let symbol: String
    let color: Color
}

/// The summary hero: score ring + a column of labeled stats.
struct ScoreHero: View {
    var score: Int
    var accent: Color
    var caption: String?
    var stats: [HeroStat]

    var body: some View {
        HStack(spacing: Spacing.lg) {
            ScoreRing(score: score, accent: accent, caption: caption, size: 120)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(stats) { stat in
                    LabeledContent {
                        Text(stat.value)
                            .font(.headline).monospacedDigit()
                            .foregroundStyle(AppColor.label)
                    } label: {
                        Label {
                            Text(stat.label).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
                        } icon: {
                            Image(systemName: stat.symbol).font(.footnote).foregroundStyle(stat.color)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

#Preview {
    ScoreHero(score: 72, accent: AppColor.recovery, caption: "Good", stats: [
        HeroStat(label: "HRV", value: "48 ms", symbol: "waveform.path.ecg", color: AppColor.recovery),
        HeroStat(label: "Resting HR", value: "54 bpm", symbol: "heart.fill", color: AppColor.recovery),
        HeroStat(label: "Strain", value: "8.4", symbol: "flame.fill", color: AppColor.strain),
        HeroStat(label: "Sleep", value: "86", symbol: "bed.double.fill", color: AppColor.sleep)
    ])
    .padding()
    .background(AppColor.background)
}
