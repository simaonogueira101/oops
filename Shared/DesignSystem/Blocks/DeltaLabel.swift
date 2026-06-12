import SwiftUI

/// A small "▲ 44" delta — an arrow tinted by direction plus the muted baseline value.
struct DeltaLabel: View {
    var info: DeltaInfo
    var upIsGood: Bool = true
    /// When set, the arrow uses this hue (so a domain view stays single-color); the signed
    /// number still carries the direction. Defaults to the semantic up-good/down-bad color.
    var tint: Color?

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Text(info.value, format: .number.precision(.fractionLength(0)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Image(systemName: info.direction.symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint ?? info.direction.color(upIsGood: upIsGood))
            Text(info.value - info.baseline,
                 format: .number.sign(strategy: .always()).precision(.fractionLength(0)))
                .font(.caption)
                .foregroundStyle(AppColor.secondaryLabel)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(info.value)), \(info.direction == .up ? "up" : info.direction == .down ? "down" : "unchanged") \(Int(abs(info.value - info.baseline))) from \(Int(info.baseline))")
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        DeltaLabel(info: DeltaInfo(value: 48, baseline: 44))
        DeltaLabel(info: DeltaInfo(value: 52, baseline: 58), upIsGood: false)
    }
    .padding()
    .background(AppColor.background)
}
