import Foundation

extension RingProtocol {
    /// `0x37` with a single DAY-INDEX byte (`37 00` today … `37 06` six days ago) — matches the
    /// official app, which loops the week as `37 00`…`37 06`. (A timestamp payload returned
    /// nothing.) `dayOffset` 0 = today.
    static func stressHistoryCommand(dayOffset: Int) -> Data {
        makePacket(command: 0x37, payload: [UInt8(max(0, min(255, dayOffset)))])
    }

    static func stressHistoryComplete(_ packets: [Data]) -> Bool {
        guard let header = packets.first(where: { $0.count > 2 && $0[$0.startIndex + 1] == 0 }) else { return false }
        return packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }.count >= Int(header[header.startIndex + 2])
    }

    static func parseStress(_ packets: [Data], dayStart: Date) -> [MetricSample] {
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
