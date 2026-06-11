import SwiftUI

/// A small "▲ 44" delta — an arrow tinted by direction plus the muted baseline value.
struct DeltaLabel: View {
    var info: DeltaInfo
    var upIsGood: Bool = true

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: info.direction.symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(info.direction.color(upIsGood: upIsGood))
            Text(info.baseline, format: .number.precision(.fractionLength(0)))
                .font(.caption)
                .foregroundStyle(AppColor.secondaryLabel)
        }
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
