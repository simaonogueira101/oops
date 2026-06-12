import SwiftUI

/// A large hero metric value with an optional trailing unit.
struct HeroNumber: View {
    var value: String
    var unit: String?
    var accent: Color = AppColor.label

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
            Text(value).metricValueStyle().foregroundStyle(accent)
            if let unit {
                Text(unit).font(.title3).foregroundStyle(AppColor.secondaryLabel)
            }
        }
    }
}

#Preview {
    HeroNumber(value: "8.4", unit: "strain", accent: AppColor.strain).padding()
}
