import SwiftUI

/// A score donut with the number (and an optional caption) centered inside it.
struct ScoreRing: View {
    var score: Int
    var accent: Color
    var caption: String?
    var size: CGFloat = 120
    @ScaledMetric(relativeTo: .largeTitle) private var typeScale: CGFloat = 1

    var body: some View {
        ZStack {
            RingChart(value: Double(score) / 100, color: accent)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColor.label)
                    .minimumScaleFactor(0.5)
                if let caption {
                    Text(caption).font(.caption2).foregroundStyle(AppColor.secondaryLabel)
                }
            }
        }
        .frame(width: size * typeScale, height: size * typeScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100\(caption.map { ", " + $0 } ?? "")")
    }
}

#Preview {
    ScoreRing(score: 72, accent: AppColor.recovery, caption: "Good").padding()
}
