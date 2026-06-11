import SwiftUI

/// A simple welcome / onboarding tour for the iPhone app (distinct from the macOS setup flow).
/// Reachable from Settings; not yet wired into first launch.
struct WelcomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "sparkles")
                    .font(.headerGlyph)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppColor.accent)
                Text("Welcome to Oops").font(.title.bold())

                feature("circle.dashed", "Pair your ring", "Bring your Colmi R09 close and keep it charged.")
                feature("moon", "Track your sleep", "Stages, HRV, and recovery — every night.")
                feature("heart", "Understand recovery", "See how ready your body is each morning.")
                feature("bell.badge", "Stay in the loop", "Allow notifications for daily insights.")

                Button("Get started") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppColor.accent)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .background(AppColor.background)
        .inlineNavigationTitle("Welcome")
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: symbol).font(.title2).foregroundStyle(AppColor.accent).frame(width: 32)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
            }
            Spacer()
        }
    }
}

#Preview {
    NavigationStack { WelcomeView() }
}
