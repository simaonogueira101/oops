import Foundation

/// The ring's battery state, parsed from a `0x03` response packet.
struct BatteryStatus: Equatable {
    let level: Int
    let isCharging: Bool
}

/// Pure, transport-agnostic encoding/decoding of the Colmi ring's 16-byte BLE protocol.
/// No CoreBluetooth, no I/O — fully unit-testable.
enum RingProtocol {
    /// Builds a 16-byte command packet: byte[0] = command, bytes[1...14] = payload
    /// (zero-padded), byte[15] = checksum = sum(bytes[0..<15]) % 255.
    static func makePacket(command: UInt8, payload: [UInt8] = []) -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = command
        for (offset, byte) in payload.prefix(14).enumerated() {
            bytes[1 + offset] = byte
        }
        let checksum = bytes[0..<15].reduce(0) { $0 + Int($1) } % 255
        bytes[15] = UInt8(checksum)
        return Data(bytes)
    }

    /// Command `0x03`: request the ring's battery level + charging state.
    static func batteryCommand() -> Data {
        makePacket(command: 0x03)
    }

    /// Parses a `0x03` battery response: byte[1] = level (%), byte[2] = charging.
    /// Returns `nil` for a packet too short to contain those fields.
    static func parseBattery(_ data: Data) -> BatteryStatus? {
        guard data.count >= 3 else { return nil }
        let level = Int(data[data.startIndex + 1])
        let isCharging = data[data.startIndex + 2] != 0
        return BatteryStatus(level: level, isCharging: isCharging)
    }

    /// 4-byte little-endian encoding (ring uses LE Unix timestamps).
    static func uint32LE(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
         UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
    }

    /// Binary-coded decimal: 26 -> 0x26. The ring's clock uses BCD.
    static func bcd(_ value: Int) -> UInt8 {
        UInt8((value / 10) * 16 + (value % 10))
    }

    /// UTC midnight (start of `date`'s day in the given calendar) as a Unix timestamp.
    static func utcMidnightUnix(for date: Date, calendar: Calendar) -> UInt32 {
        UInt32(calendar.startOfDay(for: date).timeIntervalSince1970)
    }
}
