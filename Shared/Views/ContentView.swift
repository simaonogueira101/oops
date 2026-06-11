import SwiftUI
import SwiftData

/// Composition root for the battery UI: builds the `RingManager` from the environment's
/// model context, picking the real or mock transport via `RingTransportFactory` on iOS.
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
                #if os(iOS)
                let transport = RingTransportFactory.make()
                #else
                let transport: any RingTransport = MockRingTransport()
                #endif
                manager = RingManager(transport: transport, modelContext: modelContext)
            }
        }
    }
}
