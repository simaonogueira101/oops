import SwiftUI

/// The menu-bar popover: a "Ring" tab with the shared battery screen, and a "Mac" tab
/// with synced-from-iPhone data, the auto-redeploy monitor, and access to setup.
struct MenuBarRootView: View {
    @Bindable var setup: SetupModel
    @Bindable var redeploy: RedeployService
    @Bindable var inbox: SyncInbox
    @Environment(\.openWindow) private var openWindow
    @State private var tab = Tab.ring
    @State private var justUpdated = false

    enum Tab { case ring, mac }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Ring").tag(Tab.ring)
                Text("Mac").tag(Tab.mac)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(Spacing.xs)

            Divider()

            switch tab {
            case .ring:
                ContentView()
            case .mac:
                ScrollView {
                    syncedSection
                    Divider().padding(.horizontal, Spacing.md)
                    RedeployMonitorView(service: redeploy)
                    Divider().padding(.horizontal, Spacing.md)
                    setupButton
                    versionFooter
                }
            }
        }
        .task {
            inbox.start()
            let lastSeen = UserDefaults.standard.integer(forKey: "lastSeenBuildMac")
            if BuildInfo.build > lastSeen, lastSeen > 0 { justUpdated = true }
            UserDefaults.standard.set(BuildInfo.build, forKey: "lastSeenBuildMac")
        }
    }

    private var versionFooter: some View {
        VStack(spacing: Spacing.xxs) {
            if justUpdated {
                Label("Updated to build \(BuildInfo.build)", systemImage: "checkmark.seal.fill")
                    .font(.caption).foregroundStyle(.green)
            }
            Text(BuildInfo.label).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.sm)
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
                    .foregroundStyle(setup.isComplete ? .green : .blue)
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
}
