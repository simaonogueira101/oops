import SwiftUI

/// Round avatar: photo if set, else initials, else an SF Symbol — like Apple Health.
struct Avatar: View {
    let profile: ProfileStore
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let data = profile.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if !profile.initials.isEmpty {
                Circle().fill(.tint.opacity(0.2))
                    .overlay(Text(profile.initials).font(.subheadline.weight(.semibold)).foregroundStyle(.tint))
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
