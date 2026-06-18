import Foundation

extension RingProtocol {
    /// `0x3A`: enable all-day temperature monitoring on the V1 channel. Without this the ring
    /// returns no temperature history (the upstream "stuck fetching" bug).
    static func enableAllDayTemperatureCommand() -> Data { makePacket(command: 0x3A, payload: [0x03, 0x02, 0x01]) }
}

/// The ring's "Big Data V2" channel — a SEPARATE GATT service with variable-length,
/// un-checksummed framing. Body temperature lives here, not on the 16-byte V1 protocol, so it
/// never goes through `RingProtocol.makePacket`.
enum RingBigData {
    static let serviceUUID = "de5bf728-d711-4e47-af26-65e3012a5dc7"
    static let writeUUID = "de5bf72a-d711-4e47-af26-65e3012a5dc7"
    static let notifyUUID = "de5bf729-d711-4e47-af26-65e3012a5dc7"

    /// Raw historical-temperature request (NOT padded, NO checksum). `0xBC`=Big Data V2,
    /// `0x25`=temperature; `01 00`=LE length; `3E 81 02`=fixed trailer observed in QRing traffic.
    static func temperatureRequest() -> Data { Data([0xBC, 0x25, 0x01, 0x00, 0x3E, 0x81, 0x02]) }

    /// Header [0xBC, 0x25, len_lo, len_hi]; complete when the declared payload length is in hand.
    static func temperatureComplete(_ packets: [Data]) -> Bool {
        let all = packets.reduce(Data(), +)
        guard all.count >= 4, all[all.startIndex] == 0xBC, all[all.startIndex + 1] == 0x25 else { return false }
        let len = Int(all[all.startIndex + 2]) | Int(all[all.startIndex + 3]) << 8
        return all.count >= 4 + len
    }

    static func parseTemperature(_ packets: [Data], today: Date, calendar: Calendar) -> [TemperatureReading] {
        let all = Array(packets.reduce(Data(), +))
        guard all.count > 6, all[0] == 0xBC, all[1] == 0x25 else { return [] }
        let todayStart = calendar.startOfDay(for: today)
        var readings: [TemperatureReading] = []
        var i = 6                                   // per-day blocks begin at index 6
        while i + 2 + 48 <= all.count {             // [days_ago][skip 0x1E][48 slots]
            let daysAgo = Int(all[i])
            let blockStart = i + 2
            guard let dayStart = calendar.date(byAdding: .day, value: -daysAgo, to: todayStart) else { break }
            for slot in 0..<48 {
                let raw = Int(all[blockStart + slot]) & 0xFF
                if raw > 0 {
                    readings.append(TemperatureReading(date: dayStart.addingTimeInterval(Double(slot) * 1800),
                                                       celsius: Double(raw) / 10.0 + 20.0))
                }
            }
            i = blockStart + 48
        }
        return readings
    }
}

struct TemperatureReading: Equatable {
    let date: Date
    let celsius: Double
}
