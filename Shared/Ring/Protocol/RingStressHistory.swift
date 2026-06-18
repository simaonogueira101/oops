import Foundation

extension RingProtocol {
    static func stressHistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x37, payload: uint32LE(utcMidnightUnix(for: day, calendar: calendar)))
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
