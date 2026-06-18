import Foundation

extension RingProtocol {
    static func liveSpO2StartCommand() -> Data { makePacket(command: 0x69, payload: [0x03, 0x01]) }

    static func parseLiveSpO2(_ data: Data) -> Int? {
        guard data.count >= 4 else { return nil }
        let b = Array(data)
        guard b[0] == 0x69, b[1] == 3, b[2] == 0 else { return nil }
        return b[3] > 0 ? Int(b[3]) : nil
    }

    static func spo2HistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x2C, payload: uint32LE(utcMidnightUnix(for: day, calendar: calendar)))
    }

    static func spo2HistoryComplete(_ packets: [Data]) -> Bool {
        guard let header = packets.first(where: { $0.count > 2 && $0[$0.startIndex + 1] == 0 }) else { return false }
        return packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }.count >= Int(header[header.startIndex + 2])
    }

    static func parseSpO2History(_ packets: [Data], dayStart: Date) -> [MetricSample] {
        guard let header = packets.first(where: { $0.count > 3 && $0[$0.startIndex + 1] == 0 }) else { return [] }
        let interval = TimeInterval(max(1, Int(header[header.startIndex + 3])) * 60)
        var samples: [MetricSample] = []; var slot = 0
        for packet in packets.filter({ $0.count > 1 && $0[$0.startIndex + 1] != 0 }) {
            for value in Array(packet)[2..<min(15, packet.count)] {   // bytes[2..14]; byte[15] is checksum
                if value > 0 { samples.append(MetricSample(date: dayStart.addingTimeInterval(Double(slot) * interval), value: Double(value))) }
                slot += 1
            }
        }
        return samples
    }
}
