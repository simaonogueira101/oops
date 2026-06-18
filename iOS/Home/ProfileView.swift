import SwiftUI
import PhotosUI
import SwiftData

/// Profile + preferences: photo & name (stored locally), appearance, goals, units,
/// notifications, and about. The app's single settings surface.
struct ProfileView: View {
    let profile: ProfileStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var ringMetas: [RingSyncMeta]
    @State private var pickerItem: PhotosPickerItem?
    @State private var name = ""
    @AppStorage("appTheme") private var theme: AppTheme = .system
    @AppStorage("useMetric") private var useMetric = true
    @AppStorage("stepGoal") private var stepGoal = 12000
    @AppStorage("sleepReminders") private var sleepReminders = true
    @AppStorage("recoveryAlerts") private var recoveryAlerts = true

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

                Section("Goals") {
                    Stepper("Step goal: \(stepGoal.formatted(.number))",
                            value: $stepGoal, in: 2000...30000, step: 1000)
                }

                Section("Units") {
                    Toggle("Metric units", isOn: $useMetric)
                }

                Section {
                    if let meta = ringMetas.first, meta.boundRingID != nil {
                        LabeledContent("Paired ring", value: meta.boundRingName ?? "Paired ring")
                        Button("Forget ring", role: .destructive) {
                            meta.boundRingID = nil
                            meta.boundRingName = nil
                            try? modelContext.save()
                        }
                    } else {
                        Text("No ring paired yet")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Ring")
                } footer: {
                    Text("Anyone with a Bluetooth app nearby can read this ring — binding only controls which ring this app uses.")
                }

                Section("Notifications") {
                    Toggle("Sleep reminders", isOn: $sleepReminders)
                    Toggle("Recovery alerts", isOn: $recoveryAlerts)
                }

                Section {
                    LabeledContent("Version", value: BuildInfo.label)
                    NavigationLink("Welcome tour") { WelcomeView() }
                } header: {
                    Text("About")
                } footer: {
                    Text("Your Mac auto-installs new builds when you commit, so this updates on its own.")
                }
            }
            .drawerTitle("Profile")
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
