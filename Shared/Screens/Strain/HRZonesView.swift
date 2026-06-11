import SwiftUI

struct HRZonesView: View {
    var body: some View {
        ContentUnavailableView("Heart-Rate Zones", systemImage: "heart.text.square",
                               description: Text("Zone breakdown arrives with the ring."))
            .inlineNavigationTitle("Zones")
    }
}
