import SwiftUI
import SwiftData

/// The macOS companion: a menu-bar app showing the same screens as the iPhone app,
/// plus a guided setup wizard for installing Oops onto the iPhone.
@main
struct OopsMacApp: App {
    @State private var setup = SetupModel()
    @State private var redeploy = RedeployService()

    var body: some Scene {
        MenuBarExtra("Oops", systemImage: "circle.dashed") {
            MenuBarRootView(setup: setup, redeploy: redeploy)
                .frame(width: 340, height: 560)
        }
        .menuBarExtraStyle(.window)
        // Local-only SwiftData store (the Mac is the sync hub; no CloudKit).
        .modelContainer(for: BatteryReading.self)

        Window("Set up Oops", id: "setup") {
            OnboardingView(setup: setup)
        }
        .windowResizability(.contentSize)
    }
}
