import Foundation

/// A simulated ring. Responds to command packets with realistic responses built via
/// `RingProtocol`, so the whole app runs end-to-end before the hardware arrives.
@MainActor
final class MockRingTransport: RingTransport {
    var batteryLevel: Int
    var isCharging: Bool

    init(batteryLevel: Int = 72, isCharging: Bool = false) {
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
    }

    func connect() async throws {}
    func disconnect() {}

    func send(_ command: Data) async throws -> Data {
        switch command.first {
        case 0x03:
            return RingProtocol.makePacket(
                command: 0x03,
                payload: [UInt8(batteryLevel), isCharging ? 1 : 0]
            )
        default:
            throw RingError.unsupportedCommand
        }
    }

    func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data] {
        switch command.first {
        case 0x15: return MockRingTransport.hrHistoryPackets()
        case 0x43: return MockRingTransport.activityPackets()
        case 0x44: return MockRingTransport.sleepPackets()
        case 0x37: return MockRingTransport.stressPackets()
        case 0x2C: return MockRingTransport.spo2Packets()
        default:   return [try await send(command)]
        }
    }

    // MARK: - Deterministic packet builders

    /// HR history: subtype 0 = header (count=1, interval=1 min), subtype 1 = data packet.
    private static func hrHistoryPackets() -> [Data] {
        // Header: cmd=0x15, subtype=0, dataPacketCount=1, intervalMinutes=1
        let header = makeRaw([0x15, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
                               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Data packet: subtype=1, seq=0, timestamp LE (epoch 0), then 9 HR values
        let data = makeRaw([0x15, 0x01, 0x00, 0x00, 0x00, 0x00, 60, 62, 64, 66, 68, 70, 72, 74, 76, 0x00])
        return [header, data]
    }

    /// Activity history: header declares 1 data packet, then 1 data packet.
    private static func activityPackets() -> [Data] {
        // Header: cmd=0x43, calorieScale=0, count=1
        let header = makeRaw([0x43, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
                               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Data: BCD date 2000-01-01, idx=0, calories=100 LE, steps=1000 LE, dist=500 LE
        let data = makeRaw([0x43, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x64,
                             0x00, 0xE8, 0x03, 0xF4, 0x01, 0x00, 0x00, 0x00])
        return [header, data]
    }

    /// Sleep history: subtype byte[1]==0 is header (count=1), byte[1]!=0 is data.
    private static func sleepPackets() -> [Data] {
        // Header: cmd=0x44, subtype=0, dataCount=1, interval=1
        let header = makeRaw([0x44, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
                               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Data: subtype=1, then stage/duration pairs: stage 1 (light) for 30 min, stage 2 (deep) for 20 min
        let data = makeRaw([0x44, 0x01, 0x01, 30, 0x02, 20, 0x00, 0x00,
                             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        return [header, data]
    }

    /// Stress history: same header/data layout as sleep.
    private static func stressPackets() -> [Data] {
        // Header: cmd=0x37, subtype=0, dataCount=1, intervalMinutes=30
        let header = makeRaw([0x37, 0x00, 0x01, 30, 0x00, 0x00, 0x00, 0x00,
                               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Data: subtype=1, then 13 stress values (bytes[2..14])
        let data = makeRaw([0x37, 0x01, 40, 42, 38, 45, 50, 48, 44, 41,
                             39, 43, 47, 46, 44, 0x00])
        return [header, data]
    }

    /// SpO2 history: same header/data layout as stress.
    private static func spo2Packets() -> [Data] {
        // Header: cmd=0x2C, subtype=0, dataCount=1, intervalMinutes=5
        let header = makeRaw([0x2C, 0x00, 0x01, 0x05, 0x00, 0x00, 0x00, 0x00,
                               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Data: subtype=1, then SpO2 values
        let data = makeRaw([0x2C, 0x01, 97, 96, 98, 97, 95, 98, 97, 96,
                             98, 97, 96, 95, 97, 0x00])
        return [header, data]
    }

    private static func makeRaw(_ bytes: [UInt8]) -> Data { Data(bytes) }
}
