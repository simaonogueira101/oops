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

    // MARK: Ring binding

    /// Returns the single `RingSyncMeta` record, creating and inserting one if none exists.
    private func syncMeta() throws -> RingSyncMeta {
        let existing = try modelContext.fetch(FetchDescriptor<RingSyncMeta>())
        if let meta = existing.first { return meta }
        let meta = RingSyncMeta()
        modelContext.insert(meta)
        return meta
    }

    func refreshBattery() async {
        // One read at a time: the BLE transport connects, does one job, disconnects, so
        // overlapping calls (cold-launch + foreground, or a periodic tick landing on a manual
        // read) would contend for the same radio.
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        bluetoothUnavailable = false
        defer { isBusy = false }

        do {
            // Apply any existing ring binding before connecting so the transport only
            // connects to the previously-paired ring (or any R09 ring on first launch).
            if let meta = try? syncMeta() {
                transport.boundRingID = meta.boundRingID.flatMap(UUID.init(uuidString:))
            }

            try await transport.connect()

            // After the first successful connect, persist the binding so future connects
            // go straight to this ring without scanning by name.
            if let meta = try? syncMeta(), meta.boundRingID == nil,
               let connectedID = transport.connectedRingID {
                meta.boundRingID = connectedID.uuidString
                meta.boundRingName = transport.connectedRingName
                try? modelContext.save()
            }

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
