import SwiftUI

/// Progress toward a goal, as either a ring or a labelled bar.
struct GoalProgress: View {
    var current: Double
    var goal: Double
    var accent: Color
    var unit: String
    var style: Style = .bar

    enum Style { case ring, bar }

    private var fraction: Double { goal > 0 ? min(current / goal, 1) : 0 }

    var body: some View {
        switch style {
        case .ring:
            ZStack {
                RingChart(value: fraction, color: accent)
                Text("\(Int(fraction * 100))%").font(.headline)
            }
            .frame(width: 96, height: 96)
        case .bar:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("\(Int(current)) / \(Int(goal)) \(unit)").font(.subheadline.weight(.semibold))
                ProgressView(value: fraction).tint(accent)
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        GoalProgress(current: 9240, goal: 12000, accent: AppColor.strain, unit: "steps")
        GoalProgress(current: 9240, goal: 12000, accent: AppColor.strain, unit: "steps", style: .ring)
    }
    .padding()
    .background(AppColor.background)
}
