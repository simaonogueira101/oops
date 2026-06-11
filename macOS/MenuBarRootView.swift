import SwiftUI

/// The menu-bar popover: a "Ring" tab with the shared battery screen, and a "Mac" tab
/// with synced-from-iPhone data, the auto-redeploy monitor, and access to setup.
struct MenuBarRootView: View {
    @Bindable var setup: SetupModel
    @Bindable var redeploy: RedeployService
    @Bindable var inbox: SyncInbox
    @Environment(\.openWindow) private var openWindow
    @State private var tab = Tab.ring

    enum Tab { case ring, mac }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Ring").tag(Tab.ring)
                Text("Mac").tag(Tab.mac)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            Divider()

            switch tab {
            case .ring:
                ContentView()
            case .mac:
                ScrollView {
                    syncedSection
                    Divider().padding(.horizontal, 14)
                    RedeployMonitorView(service: redeploy)
                    Divider().padding(.horizontal, 14)
                    setupButton
                }
            }
        }
        .task { inbox.start() }
    }

    private var syncedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .padding(14)
    }

    private var setupButton: some View {
        Button { openWindow(id: "setup") } label: {
            HStack(spacing: 8) {
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
        .padding(14)
    }
}
