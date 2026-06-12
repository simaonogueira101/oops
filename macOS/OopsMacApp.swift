import SwiftUI
import SwiftData
import AppKit

/// Starts the Bonjour sync listener at launch so the iPhone can push anytime.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let inbox = SyncInbox()
    func applicationDidFinishLaunching(_ notification: Notification) {
        inbox.start()
    }
}

/// The macOS companion: a menu-bar app showing the same screens as the iPhone app,
/// the auto-redeploy monitor, synced-from-iPhone data, and a guided setup wizard.
@main
struct OopsMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var setup = SetupModel()
    @State private var redeploy = RedeployService()
    @State private var login = LoginItem()

    var body: some Scene {
        MenuBarExtra("Oops", systemImage: "circle.dashed") {
            MenuBarRootView(setup: setup, redeploy: redeploy, inbox: delegate.inbox, login: login)
                .frame(width: 340, height: 560)
        }
        .menuBarExtraStyle(.window)
        // Local-only SwiftData store (the Mac is the sync hub; no CloudKit).
        .modelContainer(for: [BatteryReading.self, WorkoutRecord.self])

        Window("Set up Oops", id: "setup") {
            OnboardingView(setup: setup)
        }
        .windowResizability(.contentSize)
    }
}
