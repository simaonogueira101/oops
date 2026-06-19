import Foundation

extension RingProtocol {
    /// `0x38`: enable HRV measurement. Payload [0x02, 0x01] = set + enable.
    /// Sent once per sync; harmless to repeat.
    static func enableHRVCommand() -> Data {
        makePacket(command: 0x38, payload: [0x02, 0x01])
    }

    /// `0x39` with an EMPTY payload (`39 00 … 39`) — matches the official app, which sends no
    /// timestamp. The ring returns the current day's HRV series. (Our earlier timestamp payload
    /// returned nothing.) The `day`/`calendar` args are kept for call-site symmetry.
    static func hrvHistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x39, payload: [])
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
