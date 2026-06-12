import SwiftUI

/// App preferences: goals, units, notifications, ring status, and about.
struct SettingsView: View {
    @State private var useMetric = true
    @State private var stepGoal = 12000
    @State private var sleepReminders = true
    @State private var recoveryAlerts = true

    var body: some View {
        Form {
            Section("Goals") {
                Stepper("Step goal: \(stepGoal.formatted(.number))", value: $stepGoal, in: 2000...30000, step: 1000)
            }
            Section("Units") {
                Toggle("Metric units", isOn: $useMetric)
            }
            Section("Notifications") {
                Toggle("Sleep reminders", isOn: $sleepReminders)
                Toggle("Recovery alerts", isOn: $recoveryAlerts)
            }
            Section("About") {
                LabeledContent("Version", value: BuildInfo.label)
                NavigationLink("Welcome tour") { WelcomeView() }
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
