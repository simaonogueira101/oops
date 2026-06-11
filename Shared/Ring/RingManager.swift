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
    /// Distinct from a generic error: Bluetooth itself is off/unauthorized, so the UI can
    /// point the user at Settings rather than offer a plain "try again".
    var bluetoothUnavailable = false

    init(transport: any RingTransport, modelContext: ModelContext) {
        self.transport = transport
        self.modelContext = modelContext
    }

    func refreshBattery() async {
        isBusy = true
        errorMessage = nil
        bluetoothUnavailable = false
        defer { isBusy = false }

        do {
            try await transport.connect()
            let response = try await transport.send(RingProtocol.batteryCommand())
            transport.disconnect()

            guard let status = RingProtocol.parseBattery(response) else {
                errorMessage = "Couldn't read the ring's battery."
                return
            }

            let now = Date()
            batteryStatus = status
            lastUpdated = now
            modelContext.insert(
                BatteryReading(timestamp: now, level: status.level, isCharging: status.isCharging)
            )
            try? modelContext.save()
        } catch let error as RingError {
            transport.disconnect()
            apply(error)
        } catch {
            transport.disconnect()
            errorMessage = "Couldn't connect to the ring."
        }
    }

    /// Maps a transport error to a specific, user-facing state.
    private func apply(_ error: RingError) {
        switch error {
        case .bluetoothUnavailable:
            bluetoothUnavailable = true
            errorMessage = "Bluetooth is off. Turn it on to reach your ring."
        case .ringNotFound:
            errorMessage = "Ring not found. Make sure it's nearby and try again."
        case .timeout:
            errorMessage = "The ring didn't respond. Try again."
        case .connectionFailed, .notConnected:
            errorMessage = "Couldn't connect to the ring. Try again."
        case .unsupportedCommand:
            errorMessage = "Couldn't read the ring's battery."
        }
    }
}
