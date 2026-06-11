import SwiftUI

/// An educational/media row: a gradient thumbnail with an icon, plus a title.
struct MediaThumbnail: View {
    var title: String
    var symbol: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [AppColor.recovery.opacity(0.5), AppColor.sleep.opacity(0.4)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: symbol).foregroundStyle(.white))
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
        }
    }
}

#Preview {
    MediaThumbnail(title: "What is Recovery?", symbol: "play.fill").padding()
}
