import SwiftUI
import SwiftData

@main
struct OopsApp: App {
    var body: some Scene {
        WindowGroup {
            iOSRootView()
        }
        // Local-only SwiftData store (no CloudKit, by design).
        .modelContainer(for: BatteryReading.self)
    }
}
