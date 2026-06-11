import SwiftUI

struct SettingsView: View {
    var body: some View {
        ContentUnavailableView("Settings", systemImage: "gearshape",
                               description: Text("Preferences and goals."))
            .inlineNavigationTitle("Settings")
    }
}
