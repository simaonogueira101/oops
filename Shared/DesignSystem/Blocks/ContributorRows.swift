import SwiftUI

/// A single contributor: a name, a 0...1 fill, and a qualitative band.
struct Contributor: Identifiable {
    let id = UUID()
    let name: String
    let fraction: Double
    let band: ScoreBand
}

/// A list of contributor rows (label + progress + band label), as on a recovery/readiness screen.
struct ContributorRows: View {
    var contributors: [Contributor]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(contributors) { contributor in
                VStack(spacing: Spacing.xxs) {
                    HStack {
                        Text(contributor.name).font(.subheadline)
                        Spacer()
                        Text(contributor.band.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(contributor.band.color)
                    }
                    ProgressView(value: contributor.fraction).tint(contributor.band.color)
                }
            }
        }
    }
}

#Preview {
    ContributorRows(contributors: [
        Contributor(name: "HRV balance", fraction: 0.8, band: .good),
        Contributor(name: "Resting heart rate", fraction: 0.65, band: .optimal),
        Contributor(name: "Body temperature", fraction: 0.4, band: .poor)
    ])
    .padding()
    .background(AppColor.background)
}
