import SwiftUI
import PhotosUI

/// Profile page: set a photo (PhotosPicker) and name, stored locally. iOS exposes no
/// "me" card / Apple Account photo to third-party apps, so this is how the avatar is set.
struct ProfileView: View {
    let profile: ProfileStore

    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var name = ""
    @AppStorage("appTheme") private var theme: AppTheme = .system

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: Spacing.sm) {
                            Avatar(profile: profile, size: 96)
                            PhotosPicker("Choose Photo", selection: $pickerItem, matching: .images)
                            if profile.imageData != nil {
                                Button("Remove Photo", role: .destructive) { profile.setImage(nil) }
                                    .font(.footnote)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, Spacing.xs)
                }

                Section("Name") {
                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $theme) {
                        ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    LabeledContent("Version", value: BuildInfo.label)
                } footer: {
                    Text("Your Mac auto-installs new builds when you commit, so this updates on its own.")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { profile.setName(name); dismiss() }
                }
            }
            .onAppear { name = profile.name }
            .onChange(of: pickerItem) { _, item in
                Task {
                    let data = try? await item?.loadTransferable(type: Data.self)
                    profile.setImage(data)
                }
            }
        }
    }
}
