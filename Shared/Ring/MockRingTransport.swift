import Foundation

/// A simulated ring. Responds to command packets with realistic responses built via
/// `RingProtocol`, so the whole app runs end-to-end before the hardware arrives.
@MainActor
final class MockRingTransport: RingTransport {
    var batteryLevel: Int
    var isCharging: Bool
    var supportsBigData: Bool = true

    // Test hooks for the V2 late-response cache-drain path (mirrors BLERingTransport): when
    // `spo2LiveReturnsEmpty` is set the live SpO2 read returns nothing, and `cachedBigData`
    // feeds `takeCachedBigData(_:)` so a test can verify RingManager recovers SpO2 from the cache.
    var cachedBigData: [UInt8: [Data]] = [:]
    var spo2LiveReturnsEmpty = false

    func takeCachedBigData(_ action: UInt8) -> [Data] {
        defer { cachedBigData[action] = nil }
        return cachedBigData[action] ?? []
    }

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
        case 0x01, 0x3A, 0x6A, 0x16, 0x38:
            // Set-time, enable temperature, live HR stop, enable HR logging, enable HRV — acknowledge.
            return RingProtocol.makePacket(command: command.first ?? 0x00)
        case 0x69, 0x1E:
            // Live HR start / keepalive — answer with a deterministic BPM frame.
            return RingProtocol.makePacket(command: 0x69, payload: [0x01, 0x00, 72])
        default:
            throw RingError.unsupportedCommand
        }
    }

    func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool, perPacketTimeout: TimeInterval) async throws -> [Data] {
        switch command.first {
        case 0x15: return MockRingTransport.hrHistoryPackets()
        case 0x43: return MockRingTransport.activityPackets()
        case 0x44: return MockRingTransport.sleepPackets()
        case 0x37: return MockRingTransport.stressPackets()
        case 0x39: return MockRingTransport.hrvPackets()
        case 0x2C: return MockRingTransport.spo2Packets()
        case 0x69: return MockRingTransport.liveHRPackets()
        default:   return [try await send(command)]
        }
    }

    func sendBigData(_ data: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data] {
        guard data.count >= 2 else { return [] }
        switch data[data.startIndex + 1] {
        case 0x25: return MockRingTransport.temperaturePackets()
        case 0x2A: return spo2LiveReturnsEmpty ? [] : MockRingTransport.spo2BigDataPackets()
        case 0x27: return MockRingTransport.sleepBigDataPackets()
        default:   return []
        }
    }

    func gather(commands: [Data], opcode: UInt8, gap: TimeInterval,
                quietPeriod: TimeInterval, maxWindow: TimeInterval) async -> [Data] {
        opcode == 0x15 ? MockRingTransport.hrHistoryPackets() : []
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

    /// HRV history: same header/data layout as stress.
    private static func hrvPackets() -> [Data] {
        // Header: cmd=0x39, subtype=0, dataCount=1, intervalMinutes=30
        let header = makeRaw([0x39, 0x00, 0x01, 30, 0x00, 0x00, 0x00, 0x00,
                               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Data: subtype=1, then 3 HRV values (ms) in bytes[2..4]
        let data = makeRaw([0x39, 0x01, 40, 45, 50, 0x00, 0x00, 0x00,
                             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
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

    /// Live HR: one response packet with BPM=72.
    private static func liveHRPackets() -> [Data] {
        // [0x69, type=1, error=0, bpm=72, ...]
        [makeRaw([0x69, 0x01, 0x00, 72, 0x00, 0x00, 0x00, 0x00,
                  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])]
    }

    /// Temperature Big-Data V2 response.
    /// Layout: [0xBC, 0x25, len_lo, len_hi] header + 2 filler bytes + one day block
    /// (daysAgo=0, 0x1E marker, 48 slots with a couple of non-zero readings).
    /// `len` = total payload after the 4-byte header = 52, so `temperatureComplete` resolves.
    private static func temperaturePackets() -> [Data] {
        // 48 slots, 30-minute each; slot 16 ≈ 08:00, slot 17 ≈ 08:30 with non-zero raw values.
        // celsius = raw / 10.0 + 20.0 → raw = 170 → 37.0 °C; raw = 165 → 36.5 °C
        var slots = [UInt8](repeating: 0, count: 48)
        slots[16] = 170   // 37.0 °C
        slots[17] = 165   // 36.5 °C
        // Payload length = 2 filler + 1 (daysAgo) + 1 (0x1E) + 48 (slots) = 52
        let lenLo: UInt8 = 52
        let lenHi: UInt8 = 0
        var bytes: [UInt8] = [0xBC, 0x25, lenLo, lenHi, 0x00, 0x00,   // header + 2 filler
                               0x00, 0x1E]                              // daysAgo=0, 0x1E marker
        bytes.append(contentsOf: slots)
        return [Data(bytes)]
    }

    /// SpO2 Big-Data V2 response (0x2A).
    /// Layout: [0xBC, 0x2A, len_lo, len_hi] + 2 filler bytes + one day block:
    /// [daysAgo=0][24 hourly (min, max) pairs = 48 bytes].
    /// Hours 20–22 have non-zero readings (94, 98) to exercise parseSpO2.
    private static func spo2BigDataPackets() -> [Data] {
        // 24 pairs × 2 bytes each = 48 data bytes
        var pairs = [UInt8](repeating: 0, count: 48)
        // hours 20, 21, 22: (min=94, max=98)
        for hour in [20, 21, 22] {
            pairs[hour * 2]     = 94
            pairs[hour * 2 + 1] = 98
        }
        // Payload length = 2 filler + 1 daysAgo + 48 pairs = 51
        let len: UInt8 = 51
        var bytes: [UInt8] = [0xBC, 0x2A, len, 0x00, 0x00, 0x00,   // header + 2 filler
                               0x00]                                  // daysAgo=0
        bytes.append(contentsOf: pairs)
        return [Data(bytes)]
    }

    /// Sleep Big-Data V2 response (0x27) — SDK-correct layout.
    /// Header: [0xBC, 0x27, len_lo, len_hi, crc_lo, crc_hi] (built by bigDataRequest)
    /// Payload: [indicator=1] + one day block:
    ///   [dayOffset=0, blockLenField=8, 0, 0, endMin_lo, endMin_hi, 2, 30, 3, 20]
    /// endMinutes = 480 (8am); blockLen = 10, blockLenField = 8.
    /// light 30 min + deep 20 min → total=50min, startTime = 7:10am.
    private static func sleepBigDataPackets() -> [Data] {
        let dayBlock: [UInt8] = [
            0x00,         // dayOffset = 0
            0x08,         // blockLenField = blockLen - 2 = 10 - 2 = 8
            0x00, 0x00,   // discarded
            0xE0, 0x01,   // endMinutes = 480 LE (0xE0 | 0x01<<8 = 224+256 = 480)
            0x02, 30,     // light, 30 min
            0x03, 20      // deep, 20 min
        ]
        let payload: [UInt8] = [0x01] + dayBlock   // indicator=1 + day block
        return [RingBigData.bigDataRequest(action: 0x27, payload: payload)]
    }

    private static func makeRaw(_ bytes: [UInt8]) -> Data { Data(bytes) }
}
