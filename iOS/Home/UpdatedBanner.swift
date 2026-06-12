import SwiftUI

/// Briefly shown when the app is reopened on a newer build (the redeploy reinstalled it).
struct UpdatedBanner: View {
    let build: Int
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(AppColor.positive)
            Text("Updated to build \(build)").font(.subheadline.weight(.medium))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
        .transition(.move(edge: .top).combined(with: .opacity))
        .task {
            try? await Task.sleep(for: .seconds(5))
            onDismiss()
        }
    }
}
