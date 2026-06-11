import SwiftUI
import SwiftData

/// Composition root for the UI: builds the `RingManager` from the environment's model
/// context, wiring it to the mock transport for now (real BLE arrives with the ring).
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var manager: RingManager?

    var body: some View {
        Group {
            if let manager {
                BatteryScreen(manager: manager)
            } else {
                ProgressView()
            }
        }
        .task {
            if manager == nil {
                manager = RingManager(
                    transport: MockRingTransport(),
                    modelContext: modelContext
                )
            }
        }
    }
}
