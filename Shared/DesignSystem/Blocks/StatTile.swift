import SwiftUI

/// A compact label + value, used in stat grids inside cards.
struct StatTile: View {
    var label: String
    var value: String
    var accent: Color = AppColor.label

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColor.secondaryLabel)
            Text(value).font(.title2.weight(.semibold)).foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HStack {
        StatTile(label: "Resting HR", value: "54 bpm", accent: AppColor.recovery)
        StatTile(label: "Calories", value: "430", accent: AppColor.strain)
    }
    .padding()
}
