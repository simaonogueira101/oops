import SwiftUI

/// The menu-bar popover: a "Ring" tab with the shared battery screen, and a "Mac" tab
/// with the auto-redeploy monitor and access to setup.
struct MenuBarRootView: View {
    @Bindable var setup: SetupModel
    @Bindable var redeploy: RedeployService
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
                    RedeployMonitorView(service: redeploy)
                    Divider().padding(.horizontal, 14)
                    setupButton
                }
            }
        }
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
