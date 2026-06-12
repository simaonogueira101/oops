import SwiftUI

/// A compact stat: sentence-case secondary label over a primary-color value, with an optional
/// small-baseline unit ("118" + "bpm") — Apple Health's stat idiom.
struct StatTile: View {
    var label: String
    var value: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(value).font(.title3.weight(.semibold)).monospacedDigit()
                if let unit {
                    Text(unit).font(.footnote).foregroundStyle(AppColor.secondaryLabel)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack {
        StatTile(label: "Resting HR", value: "54", unit: "bpm")
        StatTile(label: "Calories", value: "430", unit: "cal")
    }
    .padding()
}
