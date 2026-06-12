import SwiftUI

/// The menu-bar popover: the shared screens (Overview · Sleep · Recovery · Strain — the
/// same views the iPhone uses) plus a Mac-only tab (synced data, auto-redeploy, setup,
/// launch-at-login, version).
struct MenuBarRootView: View {
    @Bindable var setup: SetupModel
    @Bindable var redeploy: RedeployService
    @Bindable var inbox: SyncInbox
    @Bindable var login: LoginItem
    @Environment(\.openWindow) private var openWindow
    @State private var tab = Tab.overview
    @State private var justUpdated = false
    @State private var date = Date()
    @State private var recorder = WorkoutRecorder()

    enum Tab { case overview, sleep, recovery, strain, mac }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Image(systemName: "circle.grid.2x2").tag(Tab.overview)
                Image(systemName: "moon").tag(Tab.sleep)
                Image(systemName: "heart").tag(Tab.recovery)
                Image(systemName: "bolt").tag(Tab.strain)
                Image(systemName: "laptopcomputer").tag(Tab.mac)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(Spacing.xs)

            Divider()

            Group {
                switch tab {
                case .overview: OverviewView(metrics: .sample, date: $date, recorder: recorder)
                case .sleep: SleepView()
                case .recovery: RecoveryView()
                case .strain: StrainView()
                case .mac: macTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.windowBackgroundColor))
        .task {
            inbox.start()
            let lastSeen = UserDefaults.standard.integer(forKey: "lastSeenBuildMac")
            if BuildInfo.build > lastSeen, lastSeen > 0 { justUpdated = true }
            UserDefaults.standard.set(BuildInfo.build, forKey: "lastSeenBuildMac")
            await login.refresh()
        }
    }

    // MARK: Mac-only tab

    private var macTab: some View {
        ScrollView {
            syncedSection
            Divider().padding(.horizontal, Spacing.md)
            RedeployMonitorView(service: redeploy)
            Divider().padding(.horizontal, Spacing.md)
            setupButton
            Divider().padding(.horizontal, Spacing.md)
            loginToggle
            versionFooter
        }
    }

    private var syncedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Synced from iPhone", systemImage: "iphone.gen3")
                .font(.subheadline.weight(.medium))
            if let payload = inbox.lastPayload {
                HStack {
                    Text(payload.source).foregroundStyle(.secondary)
                    Spacer()
                    if let level = payload.latestLevel {
                        Text("\(level)%").font(.headline)
                    }
                }
                Text("\(payload.battery.count) reading\(payload.battery.count == 1 ? "" : "s") · \(inbox.lastSync?.formatted(.relative(presentation: .named)) ?? "")")
                    .font(.caption).foregroundStyle(.tertiary)
            } else {
                Text("Waiting for your iPhone… open Oops on your phone and tap Sync to Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
    }

    private var setupButton: some View {
        Button { openWindow(id: "setup") } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: setup.isComplete ? "checkmark.seal.fill" : "iphone.gen3")
                    .foregroundStyle(setup.isComplete ? AppColor.positive : AppColor.accent)
                Text(setup.isComplete ? "iPhone setup complete" : "Set up iPhone…")
                Spacer()
                if !setup.isComplete {
                    Text("\(setup.completedCount)/\(setup.steps.count)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(Spacing.md)
    }

    private var loginToggle: some View {
        Toggle(isOn: Binding(
            get: { login.isEnabled },
            set: { on in Task { on ? await login.enable() : await login.disable() } }
        )) {
            Label("Launch at login", systemImage: "power")
        }
        .padding(Spacing.md)
    }

    private var versionFooter: some View {
        VStack(spacing: Spacing.xxs) {
            if justUpdated {
                Label("Updated to build \(BuildInfo.build)", systemImage: "checkmark.seal.fill")
                    .font(.caption).foregroundStyle(AppColor.positive)
            }
            Text(BuildInfo.label).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.sm)
    }
}
