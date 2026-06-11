import SwiftUI

/// The menu-bar popover: the shared battery screen plus an entry into setup.
struct MenuBarRootView: View {
    @Bindable var setup: SetupModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            ContentView()

            Divider()

            Button {
                openWindow(id: "setup")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: setup.isComplete ? "checkmark.seal.fill" : "iphone.gen3")
                        .foregroundStyle(setup.isComplete ? .green : .blue)
                    Text(setup.isComplete ? "iPhone setup complete" : "Set up iPhone…")
                    Spacer()
                    if !setup.isComplete {
                        Text("\(setup.completedCount)/\(setup.steps.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }
}
