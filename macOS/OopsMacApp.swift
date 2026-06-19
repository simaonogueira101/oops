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
    private let container: ModelContainer

    init() {
        // Local-only SwiftData store (the Mac is the sync hub; no CloudKit). If the on-disk
        // store is incompatible after a schema change, start fresh rather than crash on launch.
        let schema = Schema([
            BatteryReading.self, WorkoutRecord.self,
            HeartRateSample.self, ActivitySample.self, SpO2Sample.self, StressSample.self,
            TemperatureSample.self, HRVSample.self, SleepSessionRecord.self, SleepStageIntervalRecord.self
        ])
        let config = ModelConfiguration(schema: schema)
        if let existing = try? ModelContainer(for: schema, configurations: config) {
            container = existing
        } else {
            try? FileManager.default.removeItem(at: config.url)
            container = try! ModelContainer(for: schema, configurations: config)
        }
    }

    var body: some Scene {
        MenuBarExtra("Oops", systemImage: "circle.dashed") {
            MenuBarRootView(setup: setup, redeploy: redeploy, inbox: delegate.inbox, login: login)
                .frame(width: 340, height: 560)
                .task { delegate.inbox.modelContext = container.mainContext }
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Window("Set up Oops", id: "setup") {
            OnboardingView(setup: setup)
        }
        .windowResizability(.contentSize)
    }
}
