import Foundation
import CoreBluetooth
import os

/// Real CoreBluetooth implementation of `RingTransport` for the Colmi R09.
///
/// Follows the ring's documented flow: scan by service UUID → connect → discover the
/// write/notify characteristics → enable notifications, then each `send` writes a 16-byte
/// command and awaits the matching notify packet. The R09's Realtek BLE stack is flaky, so
/// the pattern is **connect → do one job → disconnect**, with a bounded connect retry, and
/// characteristics are re-discovered on every reconnect.
///
/// CoreBluetooth cannot run in the Simulator or CI, so this is verified manually on a
/// physical iPhone (per the design spec). The pure protocol it relies on (`RingProtocol`)
/// and the orchestration around it (`RingManager`) are unit-tested.
@MainActor
final class BLERingTransport: NSObject, RingTransport {
    // Nordic-UART-style GATT service exposed by the ring.
    private let serviceUUID = RingScanMatcher.serviceUUID
    private let writeUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let notifyUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    // Bring-up observability. `Logger` feeds Console.app; the `print` mirror makes the same
    // lines show up in `devicectl --console` capture over USB. Remove once assumptions hold.
    private let log = Logger(subsystem: "com.simao.oops", category: "BLE")
    private func trace(_ message: String) {
        log.notice("\(message, privacy: .public)")
        print("BLE: \(message)")
    }

    private let connectTimeout: Double = 12
    private let responseTimeout: Double = 8
    private let maxConnectAttempts = 2

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?

    private enum Stage { case idle, waitingForPowerOn, scanning, connecting, discovering, ready }
    private var stage: Stage = .idle

    private var readyContinuation: CheckedContinuation<Void, Error>?
    private var responseContinuation: CheckedContinuation<Data, Error>?
    private var connectTimeoutTask: Task<Void, Never>?
    private var responseTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: RingTransport

    func connect() async throws {
        var lastError: RingError = .connectionFailed
        for attempt in 0..<maxConnectAttempts {
            do {
                try await connectOnce()
                return
            } catch let error as RingError {
                if error == .bluetoothUnavailable { throw error }   // retrying won't help
                lastError = error
                disconnect()
                if attempt < maxConnectAttempts - 1 { try? await Task.sleep(for: .seconds(1)) }
            }
        }
        throw lastError
    }

    func disconnect() {
        connectTimeoutTask?.cancel(); connectTimeoutTask = nil
        responseTimeoutTask?.cancel(); responseTimeoutTask = nil
        if central.isScanning { central.stopScan() }
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil; writeChar = nil; notifyChar = nil; stage = .idle
        // Resolve anything still in flight so no awaiter hangs.
        readyContinuation?.resume(throwing: RingError.connectionFailed); readyContinuation = nil
        responseContinuation?.resume(throwing: RingError.notConnected); responseContinuation = nil
    }

    func send(_ command: Data) async throws -> Data {
        guard stage == .ready, let peripheral, let writeChar else { throw RingError.notConnected }
        trace("Write command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
        return try await withCheckedThrowingContinuation { continuation in
            responseContinuation = continuation
            let type: CBCharacteristicWriteType =
                writeChar.properties.contains(.write) ? .withResponse : .withoutResponse
            peripheral.writeValue(command, for: writeChar, type: type)
            responseTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(self?.responseTimeout ?? 8))
                self?.failResponse(.timeout)
            }
        }
    }

    // MARK: Connect flow

    private func connectOnce() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            readyContinuation = continuation
            startConnectFlow()
            connectTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(self?.connectTimeout ?? 12))
                guard let self else { return }
                // Nothing found yet ⇒ "ring not found"; otherwise a mid-handshake stall.
                self.failReady(self.stage == .scanning ? .ringNotFound : .connectionFailed)
            }
        }
    }

    private func startConnectFlow() {
        switch central.state {
        case .poweredOn: beginScan()
        case .unknown, .resetting: stage = .waitingForPowerOn   // delegate will call back
        default: failReady(.bluetoothUnavailable)               // off / unauthorized / unsupported
        }
    }

    private func beginScan() {
        stage = .scanning
        // The R09 (verified on real hardware, 2026-06-18) advertises its name — "R09_4301" —
        // but NOT its GATT service UUID, so a `withServices:` filter finds nothing. We must scan
        // unfiltered and match via `RingScanMatcher` (name fallback). The service UUID is still
        // present in GATT, so service/characteristic discovery after connect works normally.
        trace("Scanning for peripherals (unfiltered)…")
        central.scanForPeripherals(withServices: nil)
    }

    private func succeedReady() {
        guard let continuation = readyContinuation else { return }
        readyContinuation = nil
        connectTimeoutTask?.cancel(); connectTimeoutTask = nil
        stage = .ready
        continuation.resume()
    }

    /// Resolve the in-flight connect with a failure. Idempotent: once connect has resolved
    /// (success or failure) `readyContinuation` is nil and late delegate callbacks are ignored,
    /// so a stray post-ready callback can't throw into an already-finished — or a future — connect.
    private func failReady(_ error: RingError) {
        guard let continuation = readyContinuation else { return }
        readyContinuation = nil
        trace("Connect failed at stage \(stage): \(error)")
        connectTimeoutTask?.cancel(); connectTimeoutTask = nil
        continuation.resume(throwing: error)
    }

    private func answer(_ data: Data) {
        guard let continuation = responseContinuation else { return }
        responseContinuation = nil
        responseTimeoutTask?.cancel(); responseTimeoutTask = nil
        continuation.resume(returning: data)
    }

    private func failResponse(_ error: RingError) {
        guard let continuation = responseContinuation else { return }
        responseContinuation = nil
        responseTimeoutTask?.cancel(); responseTimeoutTask = nil
        continuation.resume(throwing: error)
    }
}

// MARK: - CBCentralManagerDelegate
//
// The central is created with `queue: .main`, so every callback below already runs on the
// main actor. `@preconcurrency` lets these main-actor methods satisfy CoreBluetooth's
// (pre-concurrency, nonisolated) delegate requirements without spurious Sendable warnings.

extension BLERingTransport: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard stage == .waitingForPowerOn else { return }
        switch central.state {
        case .poweredOn: beginScan()
        case .unknown, .resetting: break
        default: failReady(.bluetoothUnavailable)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard stage == .scanning else { return }

        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advName ?? peripheral.name
        let advUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let services = advUUIDs.map(\.uuidString).joined(separator: ",")
        trace("Discovered: name=\(name ?? "nil") rssi=\(RSSI) services=[\(services)]")

        guard RingScanMatcher.matches(name: name, advertisedServiceUUIDs: advUUIDs) else { return }

        trace("Matched ring \(name ?? "nil") — connecting")
        stage = .connecting
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stage = .discovering
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral, error: Error?) {
        failReady(.connectionFailed)
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // An unexpected drop mid-handshake fails the connect; a normal disconnect has
        // already cleared the continuations.
        if stage != .idle && stage != .ready { failReady(.connectionFailed) }
    }
}

// MARK: - CBPeripheralDelegate

extension BLERingTransport: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            return failReady(.connectionFailed)
        }
        peripheral.discoverCharacteristics([writeUUID, notifyUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let chars = service.characteristics ?? []
        guard let write = chars.first(where: { $0.uuid == writeUUID }),
              let notify = chars.first(where: { $0.uuid == notifyUUID }) else {
            return failReady(.connectionFailed)
        }
        writeChar = write
        notifyChar = notify
        peripheral.setNotifyValue(true, for: notify)   // readiness completes when this confirms
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyUUID else { return }
        if error == nil && characteristic.isNotifying {
            trace("Ring ready — notifications enabled")
            succeedReady()
        } else {
            failReady(.connectionFailed)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyUUID else { return }
        if let error {
            trace("Notify error: \(error.localizedDescription)")
            return failResponse(error as? RingError ?? .timeout)
        }
        guard let value = characteristic.value else { return failResponse(.timeout) }
        trace("Notify packet (\(value.count) bytes): \(value.map { String(format: "%02X", $0) }.joined(separator: " "))")
        answer(value)
    }
}
