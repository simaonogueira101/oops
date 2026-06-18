import SwiftUI

/// A single contributor: a name, a 0...1 fill, and a qualitative band.
/// `fraction` and `band` may be nil when the metric is unavailable (renders as "—").
struct Contributor: Identifiable {
    let id = UUID()
    let name: String
    let fraction: Double?
    let band: ScoreBand?
}

/// A list of contributor rows (label + progress + band label). Colors are shades of the
/// domain `tint` (stronger = better), keeping each screen a single hue.
struct ContributorRows: View {
    var tint: Color
    var contributors: [Contributor]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(contributors) { contributor in
                VStack(spacing: Spacing.xxs) {
                    HStack {
                        Text(contributor.name).font(.subheadline)
                        Spacer()
                        Text(contributor.band?.label ?? "—")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.secondaryLabel)
                    }
                    ProgressView(value: contributor.fraction ?? 0)
                        .tint(contributor.band.map { $0.tinted(tint) } ?? AppColor.track)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    ContributorRows(tint: AppColor.recovery, contributors: [
        Contributor(name: "HRV balance", fraction: 0.8, band: .good),
        Contributor(name: "Resting heart rate", fraction: 0.65, band: .optimal),
        Contributor(name: "Body temperature", fraction: 0.4, band: .poor)
    ])
    .padding()
    .background(AppColor.background)
}
