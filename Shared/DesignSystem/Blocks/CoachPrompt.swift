import SwiftUI

/// A tappable "Ask Oops anything…" entry pill for the AI coach.
struct CoachPrompt: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sparkles")
                Text("Ask Oops anything…").foregroundStyle(AppColor.secondaryLabel)
                Spacer()
            }
            .padding(Spacing.sm)
            .background(AppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .tint(AppColor.accent)
    }
}

#Preview {
    CoachPrompt(action: {}).padding().background(AppColor.background)
}
