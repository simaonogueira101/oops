import Foundation

extension RingProtocol {
    /// `0x38`: enable HRV measurement. Payload [0x02, 0x01] = set + enable.
    /// Sent once per sync; harmless to repeat.
    static func enableHRVCommand() -> Data {
        makePacket(command: 0x38, payload: [0x02, 0x01])
    }

    /// `0x39`: request HRV history for a given day (UTC midnight timestamp, 4-byte LE).
    /// Same shape as HR history (0x15) and stress history (0x37).
    static func hrvHistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x39, payload: uint32LE(utcMidnightUnix(for: day, calendar: calendar)))
    }

    static func hrvHistoryComplete(_ packets: [Data]) -> Bool {
        guard let header = packets.first(where: { $0.count > 2 && $0[$0.startIndex + 1] == 0 }) else { return false }
        return packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }.count >= Int(header[header.startIndex + 2])
    }

    // LAYOUT mirrors stress; verify against real HRV data on device
    static func parseHRV(_ packets: [Data], dayStart: Date) -> [MetricSample] {
        guard let header = packets.first(where: { $0.count > 3 && $0[$0.startIndex + 1] == 0 }) else { return [] }
        let interval = TimeInterval(max(1, Int(header[header.startIndex + 3])) * 60)
        let data = packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }
        var samples: [MetricSample] = []
        var slot = 0
        for packet in data {
            for value in Array(packet)[2..<min(15, packet.count)] {   // bytes[2..14]; byte[15] is checksum
                if value > 0 { samples.append(MetricSample(date: dayStart.addingTimeInterval(Double(slot) * interval), value: Double(value))) }
                slot += 1
            }
        }
        return samples
    }
}
