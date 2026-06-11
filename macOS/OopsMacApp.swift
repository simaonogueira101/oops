import SwiftUI
import SwiftData

/// The macOS companion: a menu-bar app showing the same screens as the iPhone app.
/// (Redeploy monitor and Mac↔iPhone sync land in the next steps.)
@main
struct OopsMacApp: App {
    var body: some Scene {
        MenuBarExtra("Oops", systemImage: "circle.dashed") {
            ContentView()
                .frame(width: 320, height: 480)
        }
        .menuBarExtraStyle(.window)
        // Local-only SwiftData store (the Mac is the sync hub; no CloudKit).
        .modelContainer(for: BatteryReading.self)
    }
}
