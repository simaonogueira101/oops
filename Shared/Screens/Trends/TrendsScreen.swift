import SwiftUI

struct TrendsScreen: View {
    var body: some View {
        ContentUnavailableView("Trends", systemImage: "chart.xyaxis.line",
                               description: Text("Long-term trends arrive with the ring."))
            .inlineNavigationTitle("Trends")
    }
}
