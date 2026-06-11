import SwiftUI

/// A satellite stat shown beside a `CompositeHeroRing`.
struct HeroStat: Identifiable {
    let id = UUID()
    let value: String
    let label: String
    let color: Color
}

/// A center score ring flanked by up to four satellite stats (Whoop-style overview).
struct CompositeHeroRing: View {
    var score: Int
    var accent: Color
    var leading: [HeroStat]
    var trailing: [HeroStat]

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            column(leading)
            ScoreRing(score: score, accent: accent, size: 150)
            column(trailing)
        }
    }

    private func column(_ stats: [HeroStat]) -> some View {
        VStack(spacing: Spacing.lg) {
            ForEach(stats) { stat in
                VStack(spacing: Spacing.xxs) {
                    Text(stat.value).font(.title3.weight(.semibold)).foregroundStyle(stat.color)
                    Text(stat.label.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColor.secondaryLabel)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CompositeHeroRing(
        score: 72, accent: AppColor.recovery,
        leading: [HeroStat(value: "48", label: "HRV", color: AppColor.recovery),
                  HeroStat(value: "54", label: "RHR", color: AppColor.recovery)],
        trailing: [HeroStat(value: "8.4", label: "Strain", color: AppColor.strain),
                   HeroStat(value: "86", label: "Sleep", color: AppColor.sleep)]
    )
    .padding()
    .background(AppColor.background)
}
