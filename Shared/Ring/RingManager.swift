import Foundation
import SwiftData

/// Orchestrates a battery read: connect → send command → parse → persist → publish.
/// Transport-agnostic (injected `RingTransport`), so it runs identically against the
/// mock or, later, real CoreBluetooth.
@MainActor
@Observable
final class RingManager {
    private let transport: any RingTransport
    private let modelContext: ModelContext

    var batteryStatus: BatteryStatus?
    var lastUpdated: Date?
    var isBusy = false
    var errorMessage: String?

    init(transport: any RingTransport, modelContext: ModelContext) {
        self.transport = transport
        self.modelContext = modelContext
    }

    func refreshBattery() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await transport.connect()
            let response = try await transport.send(RingProtocol.batteryCommand())
            transport.disconnect()

            guard let status = RingProtocol.parseBattery(response) else {
                errorMessage = "Couldn't read the battery."
                return
            }

            let now = Date()
            batteryStatus = status
            lastUpdated = now
            modelContext.insert(
                BatteryReading(timestamp: now, level: status.level, isCharging: status.isCharging)
            )
            try? modelContext.save()
        } catch {
            errorMessage = "Couldn't connect to the ring."
        }
    }
}
