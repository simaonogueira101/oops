import SwiftUI

/// Two concentric progress rings — recovery (outer) and strain (inner) — styled like Apple's
/// Activity / Health rings. Built on the shared `RingChart` primitive.
struct MetricRings: View {
    let recovery: Double   // 0...1
    let strain: Double     // 0...1
    var size: CGFloat = 190

    var body: some View {
        ZStack {
            RingChart(value: recovery, color: AppColor.recovery)
            RingChart(value: strain, color: AppColor.strain)
                .scaleEffect(0.72)
            Image(systemName: "circle.dashed")
                .font(.title)
                .foregroundStyle(.tertiary)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    MetricRings(recovery: 0.72, strain: 0.4).padding().background(AppColor.background)
}
