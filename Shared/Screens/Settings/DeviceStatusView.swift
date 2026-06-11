import SwiftUI

/// Ring battery and device status. Mock values until the ring is connected.
struct DeviceStatusView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Card(label: "Ring", title: "72%", accent: AppColor.recovery) {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "circle.dashed")
                            .font(.heroGlyph)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppColor.recovery)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Connected").font(.headline)
                            Text("Colmi R09").font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
                        }
                        Spacer()
                    }
                }
                Card(label: "Device") {
                    VStack(spacing: Spacing.sm) {
                        infoRow("Model", "Colmi R09")
                        infoRow("Firmware", "1.2.3")
                        infoRow("Serial", "R09-4F2A")
                    }
                }
                Card(accent: AppColor.negative, footer: .cta(title: "Forget ring", action: {})) {
                    EmptyView()
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .inlineNavigationTitle("Ring")
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(AppColor.secondaryLabel)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack { DeviceStatusView() }
}
