import SwiftUI

/// The app background with subtle domain-tinted glows (top + bottom), so the Liquid Glass cards
/// have varied color to refract. Adapts to light/dark via the system grouped background.
struct ScreenBackground: View {
    var tint: Color = AppColor.accent

    var body: some View {
        AppColor.background
            .overlay(alignment: .top) {
                RadialGradient(colors: [tint.opacity(0.22), .clear],
                               center: .top, startRadius: 0, endRadius: 480)
            }
            .overlay(alignment: .bottomTrailing) {
                RadialGradient(colors: [tint.opacity(0.13), .clear],
                               center: .bottomTrailing, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
    }
}

extension View {
    /// Replaces a flat `AppColor.background` with the tinted-glow background.
    func screenBackground(_ tint: Color = AppColor.accent) -> some View {
        background(ScreenBackground(tint: tint))
    }
}

#Preview {
    ScreenBackground(tint: AppColor.sleep)
}
