import SwiftUI

struct JournalView: View {
    var body: some View {
        ContentUnavailableView("Journal", systemImage: "tag",
                               description: Text("Tag what's going on to spot patterns."))
            .inlineNavigationTitle("Journal")
    }
}
