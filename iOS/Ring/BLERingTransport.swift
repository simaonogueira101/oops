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
    // Nordic-UART-style GATT service exposed by the ring (V1 channel).
    private let serviceUUID = RingScanMatcher.serviceUUID
    private let writeUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let notifyUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    // Big-Data V2 channel — body temperature lives on a separate GATT service.
    private let v2ServiceUUID = CBUUID(string: RingBigData.serviceUUID)
    private let v2WriteUUID = CBUUID(string: RingBigData.writeUUID)
    private let v2NotifyUUID = CBUUID(string: RingBigData.notifyUUID)

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
    private var v2WriteChar: CBCharacteristic?
    private var v2NotifyChar: CBCharacteristic?
    private(set) var supportsBigData: Bool = false

    /// When non-nil, scan will only connect to a peripheral whose `identifier` matches this UUID.
    /// Set by `RingManager` before calling `connect()` once a ring has been bound.
    var boundRingID: UUID?

    /// The identifier of the peripheral that most recently connected successfully.
    /// `RingManager` reads this after a successful connect to persist the binding.
    private(set) var connectedRingID: UUID?

    /// The advertised/peripheral name of the most recently connected ring.
    private(set) var connectedRingName: String?

    private enum Stage { case idle, waitingForPowerOn, scanning, connecting, discovering, ready }
    private var stage: Stage = .idle

    private var readyContinuation: CheckedContinuation<Void, Error>?
    private var responseContinuation: CheckedContinuation<Data, Error>?
    private var connectTimeoutTask: Task<Void, Never>?
    private var responseTimeoutTask: Task<Void, Never>?

    // Paged read state — nil when no paged read is in flight.
    private var pagedContinuation: CheckedContinuation<[Data], Error>?
    private var pagedBuffer: [Data] = []
    /// The opcode (byte[0]) of the in-flight V1 read. The ring echoes a command's opcode in its
    /// response, but echoes arrive with latency — so we only accept notify packets matching this
    /// opcode and drop stale/unsolicited ones (otherwise a delayed echo from a previous command
    /// gets mis-read as this command's response, e.g. battery returning 2% from an HRV-enable echo).
    private var expectedV1Opcode: UInt8?
    private var isCompletePredicate: (([Data]) -> Bool)?
    private var pagedTimeoutTask: Task<Void, Never>?
    private var currentPagedTimeout: TimeInterval = 8

    // Big-Data V2 read state — nil when no V2 read is in flight.
    private var bigDataContinuation: CheckedContinuation<[Data], Error>?
    private var bigDataBuffer: [Data] = []
    private var bigDataComplete: (([Data]) -> Bool)?
    private var bigDataTimeoutTask: Task<Void, Never>?
    /// The BC action byte (data[1]) of the in-flight V2 read. Late responses from a previous V2
    /// request carry a different action and are dropped so they don't corrupt this read's buffer.
    private var expectedBigDataAction: UInt8?

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
        stopKeepalive()
        connectTimeoutTask?.cancel(); connectTimeoutTask = nil
        responseTimeoutTask?.cancel(); responseTimeoutTask = nil
        if central.isScanning { central.stopScan() }
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil; writeChar = nil; notifyChar = nil
        v2WriteChar = nil; v2NotifyChar = nil; supportsBigData = false
        stage = .idle
        // Resolve anything still in flight so no awaiter hangs.
        readyContinuation?.resume(throwing: RingError.connectionFailed); readyContinuation = nil
        responseContinuation?.resume(throwing: RingError.notConnected); responseContinuation = nil
        pagedTimeoutTask?.cancel(); pagedTimeoutTask = nil
        pagedContinuation?.resume(throwing: RingError.notConnected)
        pagedContinuation = nil; pagedBuffer = []; isCompletePredicate = nil; currentPagedTimeout = 8
        expectedV1Opcode = nil; expectedBigDataAction = nil
        bigDataTimeoutTask?.cancel(); bigDataTimeoutTask = nil
        bigDataContinuation?.resume(throwing: RingError.notConnected)
        bigDataContinuation = nil; bigDataBuffer = []; bigDataComplete = nil
        v2NotifyContinuation?.resume(throwing: RingError.notConnected); v2NotifyContinuation = nil
    }

    func send(_ command: Data) async throws -> Data {
        guard stage == .ready, let peripheral, let writeChar else { throw RingError.notConnected }
        guard responseContinuation == nil, pagedContinuation == nil else { throw RingError.notConnected }
        trace("Write command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
        return try await withCheckedThrowingContinuation { continuation in
            responseContinuation = continuation
            expectedV1Opcode = command.first
            let type: CBCharacteristicWriteType =
                // Write WITHOUT response (like the tahnok client): a with-response write makes iOS
                // wait for an ATT ack each time, consuming connection events the ring needs to send
                // its notification packets back — which stalls multi-packet reads (HR's 24 pages).
                writeChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            peripheral.writeValue(command, for: writeChar, type: type)
            responseTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(self?.responseTimeout ?? 8))
                self?.failResponse(.timeout)
            }
        }
    }

    func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool, perPacketTimeout: TimeInterval) async throws -> [Data] {
        guard stage == .ready, let peripheral, let writeChar else { throw RingError.notConnected }
        guard responseContinuation == nil, pagedContinuation == nil else { throw RingError.notConnected }
        trace("Write paged command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
        return try await withCheckedThrowingContinuation { continuation in
            pagedContinuation = continuation
            pagedBuffer = []
            isCompletePredicate = isComplete
            currentPagedTimeout = perPacketTimeout
            expectedV1Opcode = command.first
            let type: CBCharacteristicWriteType =
                // Write WITHOUT response (like the tahnok client): a with-response write makes iOS
                // wait for an ATT ack each time, consuming connection events the ring needs to send
                // its notification packets back — which stalls multi-packet reads (HR's 24 pages).
                writeChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            peripheral.writeValue(command, for: writeChar, type: type)
            armPagedTimeout()
        }
    }

    /// Write a command with no response awaited — for live-HR keepalives fired during a paged
    /// read. Does not touch any continuation/buffer, so it won't disturb an in-flight read.
    func fireAndForget(_ command: Data) {
        guard stage == .ready, let peripheral, let writeChar else { return }
        trace("Fire-and-forget: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
        let type: CBCharacteristicWriteType =
            writeChar.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(command, for: writeChar, type: type)
    }

    private var keepaliveTimer: DispatchSourceTimer?

    /// A repeating main-queue timer firing the keepalive — robust against actor scheduling
    /// (unlike a Task-sleep loop, which we found only fired once during an awaited read).
    func startKeepalive(_ command: Data, interval: TimeInterval) {
        stopKeepalive()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.fireAndForget(command) }
        }
        timer.resume()
        keepaliveTimer = timer
    }

    func stopKeepalive() {
        keepaliveTimer?.cancel()
        keepaliveTimer = nil
    }

    func sendBigData(_ data: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data] {
        guard stage == .ready, let peripheral, let v2WriteChar else { throw RingError.notConnected }
        guard responseContinuation == nil, pagedContinuation == nil, bigDataContinuation == nil else {
            throw RingError.notConnected
        }
        try await enableV2NotifyIfNeeded()
        trace("Write Big-Data V2: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        return try await withCheckedThrowingContinuation { continuation in
            bigDataContinuation = continuation
            bigDataBuffer = []
            bigDataComplete = isComplete
            // Correlate the response by its BC action byte (data[1]). V2 responses are slow to
            // assemble and arrive out of order; without this, a late response from a previous
            // request (e.g. spo2's BC 2A) bleeds into this request's buffer and breaks its
            // complete-check, cascading into a timeout. Drop packets whose action != this one's.
            expectedBigDataAction = data.count > 1 ? data[data.startIndex + 1] : nil
            let type: CBCharacteristicWriteType =
                v2WriteChar.properties.contains(.write) ? .withResponse : .withoutResponse
            peripheral.writeValue(data, for: v2WriteChar, type: type)
            armBigDataTimeout()
        }
    }

    private var v2NotifyContinuation: CheckedContinuation<Void, Error>?

    /// Enables the V2 (Big-Data) notify characteristic on demand and awaits confirmation. Kept
    /// OFF during normal/live-HR operation because subscribing to it stops live-HR streaming.
    private func enableV2NotifyIfNeeded() async throws {
        guard let peripheral, let v2NotifyChar else { throw RingError.notConnected }
        if v2NotifyChar.isNotifying { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            v2NotifyContinuation = cont
            peripheral.setNotifyValue(true, for: v2NotifyChar)
        }
    }

    // Big-Data responses can be slow to assemble on the ring — the sleep hypnogram (0x27)
    // arrives ~9-10s after the request (verified on-device), past the 8s V1 timeout. Give the
    // V2 channel a longer window so the response isn't dropped just before it lands.
    private let bigDataTimeout: Double = 30

    private func armBigDataTimeout() {
        bigDataTimeoutTask?.cancel()
        bigDataTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.bigDataTimeout ?? 30))
            self?.failBigData(.timeout)
        }
    }

    private func answerBigData(_ packets: [Data]) {
        guard let continuation = bigDataContinuation else { return }
        bigDataContinuation = nil
        bigDataBuffer = []
        bigDataComplete = nil
        expectedBigDataAction = nil
        bigDataTimeoutTask?.cancel(); bigDataTimeoutTask = nil
        continuation.resume(returning: packets)
    }

    private func failBigData(_ error: RingError) {
        guard let continuation = bigDataContinuation else { return }
        bigDataContinuation = nil
        bigDataBuffer = []
        bigDataComplete = nil
        expectedBigDataAction = nil
        bigDataTimeoutTask?.cancel(); bigDataTimeoutTask = nil
        continuation.resume(throwing: error)
    }

    private func armPagedTimeout() {
        pagedTimeoutTask?.cancel()
        pagedTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.currentPagedTimeout ?? 8))
            self?.pagedTimedOut()
        }
    }

    /// A per-packet timeout on a paged read means the ring paused longer than expected — for the
    /// ring's bursty history paging that means "no more packets coming". If we already collected
    /// packets, RESOLVE with them (parse/persist what arrived and let the sync advance) instead
    /// of throwing the whole read away. Only a truly empty response is a real failure.
    private func pagedTimedOut() {
        if pagedBuffer.isEmpty {
            failPaged(.timeout)
        } else {
            answerPaged(pagedBuffer)
        }
    }

    private func answerPaged(_ packets: [Data]) {
        guard let continuation = pagedContinuation else { return }
        pagedContinuation = nil
        pagedBuffer = []
        isCompletePredicate = nil
        expectedV1Opcode = nil
        pagedTimeoutTask?.cancel(); pagedTimeoutTask = nil
        continuation.resume(returning: packets)
    }

    private func failPaged(_ error: RingError) {
        guard let continuation = pagedContinuation else { return }
        pagedContinuation = nil
        pagedBuffer = []
        isCompletePredicate = nil
        expectedV1Opcode = nil
        pagedTimeoutTask?.cancel(); pagedTimeoutTask = nil
        continuation.resume(throwing: error)
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
        // The ring is often already connected at the iOS level (it advertises only when
        // disconnected). CoreBluetooth won't surface a connected peripheral via scanning, so
        // check retrieveConnectedPeripherals first and use it directly if it's our ring.
        let known = central.retrieveConnectedPeripherals(withServices: [
            serviceUUID,
            v2ServiceUUID
        ])
        if let ring = known.first(where: {
            RingScanMatcher.matches(name: $0.name, advertisedServiceUUIDs: [],
                                    boundID: boundRingID, peripheralID: $0.identifier)
        }) {
            trace("Using already-connected ring \(ring.name ?? "nil") (retrieveConnectedPeripherals)")
            stage = .connecting
            self.peripheral = ring
            ring.delegate = self
            connectedRingName = ring.name
            central.connect(ring)
            return
        }
        // else fall through to scanning
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
        connectedRingID = peripheral?.identifier
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
        expectedV1Opcode = nil
        responseTimeoutTask?.cancel(); responseTimeoutTask = nil
        continuation.resume(returning: data)
    }

    private func failResponse(_ error: RingError) {
        guard let continuation = responseContinuation else { return }
        responseContinuation = nil
        expectedV1Opcode = nil
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

        guard RingScanMatcher.matches(name: name, advertisedServiceUUIDs: advUUIDs,
                                      boundID: boundRingID, peripheralID: peripheral.identifier) else { return }

        trace("Matched ring \(name ?? "nil") — connecting")
        stage = .connecting
        central.stopScan()
        self.peripheral = peripheral
        self.connectedRingName = name
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stage = .discovering
        peripheral.discoverServices([serviceUUID, v2ServiceUUID])
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
        // V2 service is best-effort — a ring without it still connects.
        if let v2Service = peripheral.services?.first(where: { $0.uuid == v2ServiceUUID }) {
            peripheral.discoverCharacteristics([v2WriteUUID, v2NotifyUUID], for: v2Service)
        } else {
            trace("Big-Data V2 service not found — temperature unavailable")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if service.uuid == v2ServiceUUID {
            // V2 is best-effort — failure here must NOT block V1 readiness.
            let chars = service.characteristics ?? []
            if let write = chars.first(where: { $0.uuid == v2WriteUUID }),
               let notify = chars.first(where: { $0.uuid == v2NotifyUUID }) {
                v2WriteChar = write
                v2NotifyChar = notify
                supportsBigData = true
                // Do NOT enable the V2 notify here. Subscribing to the Big-Data notify
                // characteristic stops the ring from streaming live HR (confirmed: the official
                // app keeps it OFF and enables it only for a transfer). It's enabled lazily in
                // sendBigData() — by then the live-HR read (which runs first) is already done.
                trace("Big-Data V2 chars found — notify deferred until a Big-Data read")
            } else {
                trace("Big-Data V2 chars missing")
            }
            return
        }
        // V1 service — required for readiness.
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
        if characteristic.uuid == v2NotifyUUID {
            // Resumes the lazy enableV2NotifyIfNeeded() awaiter. Does not affect V1 readiness.
            if error == nil && characteristic.isNotifying {
                trace("Big-Data V2 notifications enabled")
                v2NotifyContinuation?.resume(); v2NotifyContinuation = nil
            } else {
                trace("Big-Data V2 notification enable failed")
                v2NotifyContinuation?.resume(throwing: RingError.connectionFailed); v2NotifyContinuation = nil
            }
            return
        }
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
        // Route V2 Big-Data packets separately from V1.
        if characteristic.uuid == v2NotifyUUID {
            if let error {
                trace("V2 notify error: \(error.localizedDescription)")
                return failBigData(error as? RingError ?? .timeout)
            }
            guard let value = characteristic.value else { return failBigData(.timeout) }
            trace("V2 notify packet (\(value.count) bytes): \(value.map { String(format: "%02X", $0) }.joined(separator: " "))")
            // Drop late responses from a previous V2 request (different BC action) so they don't
            // corrupt this read's buffer. Match on byte[1]; allow the BC-header packets through.
            if let expected = expectedBigDataAction, value.count > 1,
               value[value.startIndex] == 0xBC, value[value.startIndex + 1] != expected {
                trace("…ignoring V2 (expected action \(String(format: "%02X", expected)))")
                return
            }
            bigDataBuffer.append(value)
            armBigDataTimeout()
            if bigDataComplete?(bigDataBuffer) == true {
                answerBigData(bigDataBuffer)
            }
            return
        }

        guard characteristic.uuid == notifyUUID else { return }
        if let error {
            trace("Notify error: \(error.localizedDescription)")
            if pagedContinuation != nil {
                return failPaged(error as? RingError ?? .timeout)
            }
            return failResponse(error as? RingError ?? .timeout)
        }
        guard let value = characteristic.value else {
            if pagedContinuation != nil { return failPaged(.timeout) }
            return failResponse(.timeout)
        }
        trace("Notify packet (\(value.count) bytes): \(value.map { String(format: "%02X", $0) }.joined(separator: " "))")
        // Correlate by opcode: drop stale echoes / unsolicited packets that aren't this read's
        // response, so a delayed reply from a previous command can't be mis-attributed here.
        if let expected = expectedV1Opcode, value.first != expected {
            trace("…ignoring (expected \(String(format: "%02X", expected)))")
            return
        }
        // Route to whichever V1 read is in flight.
        if pagedContinuation != nil {
            pagedBuffer.append(value)
            armPagedTimeout()   // re-arm per-packet timeout
            if isCompletePredicate?(pagedBuffer) == true {
                answerPaged(pagedBuffer)
            }
        } else {
            answer(value)
        }
    }
}
