import SwiftUI

struct DeviceStatusView: View {
    var body: some View {
        ContentUnavailableView("Ring", systemImage: "circle.dashed",
                               description: Text("Battery and device status."))
            .inlineNavigationTitle("Ring")
    }
}
