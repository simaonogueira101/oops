import Foundation

extension RingProtocol {
    static func heartRateHistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x15, payload: uint32LE(utcMidnightUnix(for: day, calendar: calendar)))
    }

    private static func hrSubtype(_ packet: Data) -> Int {
        packet.count > 1 ? Int(packet[packet.startIndex + 1]) : -1
    }

    static func heartRateHistoryComplete(_ packets: [Data]) -> Bool {
        if packets.contains(where: { hrSubtype($0) == 255 }) { return true }
        guard let header = packets.first(where: { hrSubtype($0) == 0 }), header.count >= 3 else { return false }
        let dataPacketCount = Int(header[header.startIndex + 2])
        let received = packets.filter { (1...254).contains(hrSubtype($0)) }.count
        return received >= dataPacketCount
    }

    static func parseHeartRateHistory(_ packets: [Data]) -> [MetricSample] {
        guard let header = packets.first(where: { hrSubtype($0) == 0 }), header.count >= 4 else { return [] }
        let intervalSeconds = TimeInterval(max(1, Int(header[header.startIndex + 3])) * 60)
        let data = packets.filter { (1...254).contains(hrSubtype($0)) }.sorted { hrSubtype($0) < hrSubtype($1) }
        guard let first = data.first(where: { hrSubtype($0) == 1 }), first.count >= 6 else { return [] }
        let startTS = UInt32(first[first.startIndex + 2])
            | UInt32(first[first.startIndex + 3]) << 8
            | UInt32(first[first.startIndex + 4]) << 16
            | UInt32(first[first.startIndex + 5]) << 24
        let start = Date(timeIntervalSince1970: TimeInterval(startTS))

        var samples: [MetricSample] = []
        var slot = 0
        for packet in data {
            let bytes = Array(packet)
            let values = hrSubtype(packet) == 1 ? Array(bytes[6..<16]) : Array(bytes[2..<16])
            for value in values {
                if value > 0 {
                    samples.append(MetricSample(date: start.addingTimeInterval(Double(slot) * intervalSeconds),
                                                value: Double(value)))
                }
                slot += 1
            }
        }
        return samples
    }
}
