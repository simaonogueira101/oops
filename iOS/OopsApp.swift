import SwiftUI
import SwiftData

@main
struct OopsApp: App {
    @AppStorage("appTheme") private var theme: AppTheme = .system
    private let container: ModelContainer

    init() {
        // Local-only SwiftData store (no CloudKit, by design). If the on-disk store is
        // incompatible after a schema change, start fresh rather than crash on launch.
        let schema = Schema([BatteryReading.self, SyncLogEntry.self])
        let config = ModelConfiguration(schema: schema)
        if let existing = try? ModelContainer(for: schema, configurations: config) {
            container = existing
        } else {
            try? FileManager.default.removeItem(at: config.url)
            container = try! ModelContainer(for: schema, configurations: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeRootView()
                .preferredColorScheme(theme.colorScheme)
        }
        .modelContainer(container)
    }
}
