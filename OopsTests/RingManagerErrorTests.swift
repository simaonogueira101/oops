import Foundation
import SwiftData
import Testing
@testable import Oops

/// A transport whose `connect`/`send` fail with a chosen `RingError`, so we can assert how
/// `RingManager` turns each failure into a distinct, user-facing state.
@MainActor
private final class StubTransport: RingTransport {
    var connectError: RingError?
    var sendError: RingError?

    init(connectError: RingError? = nil, sendError: RingError? = nil) {
        self.connectError = connectError
        self.sendError = sendError
    }

    func connect() async throws {
        if let connectError { throw connectError }
    }
    func disconnect() {}
    func send(_ command: Data) async throws -> Data {
        if let sendError { throw sendError }
        return RingProtocol.makePacket(command: 0x03, payload: [50, 0])
    }
    func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data] {
        [try await send(command)]
    }
    var supportsBigData: Bool { false }
    func sendBigData(_ data: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data] {
        throw RingError.notConnected
    }
}

@MainActor
struct RingManagerErrorTests {
    private func inMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: BatteryReading.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func surfacesBluetoothUnavailableAsAnExplicitState() async throws {
        let context = try inMemoryContext()
        let manager = RingManager(
            transport: StubTransport(connectError: .bluetoothUnavailable),
            modelContext: context
        )

        await manager.refreshBattery()

        #expect(manager.bluetoothUnavailable == true)
        #expect(manager.errorMessage?.contains("Bluetooth") == true)
        #expect(manager.batteryStatus == nil)
        #expect(try context.fetch(FetchDescriptor<BatteryReading>()).isEmpty)
    }

    @Test func mapsRingNotFoundToARetryMessageWithoutTheBluetoothFlag() async throws {
        let manager = RingManager(
            transport: StubTransport(connectError: .ringNotFound),
            modelContext: try inMemoryContext()
        )

        await manager.refreshBattery()

        #expect(manager.bluetoothUnavailable == false)
        #expect(manager.errorMessage?.localizedCaseInsensitiveContains("not found") == true)
    }

    @Test func successfulReadClearsAnyPriorBluetoothUnavailableState() async throws {
        let context = try inMemoryContext()
        // First, a failed read leaves the Bluetooth-unavailable state set.
        let failing = RingManager(transport: StubTransport(connectError: .bluetoothUnavailable), modelContext: context)
        await failing.refreshBattery()
        #expect(failing.bluetoothUnavailable == true)

        // A subsequent successful read (mock transport) must clear it.
        let manager = RingManager(transport: MockRingTransport(batteryLevel: 80, isCharging: false), modelContext: context)
        await manager.refreshBattery()

        #expect(manager.bluetoothUnavailable == false)
        #expect(manager.errorMessage == nil)
        #expect(manager.batteryStatus == BatteryStatus(level: 80, isCharging: false))
    }
}
