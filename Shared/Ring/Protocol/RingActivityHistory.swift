import Foundation

struct ActivitySamplePoint: Equatable {
    let date: Date
    let steps: Int
    let calories: Int
    let distanceMeters: Int
}

extension RingProtocol {
    static func activityHistoryCommand(dayOffset: Int) -> Data {
        makePacket(command: 0x43, payload: [UInt8(dayOffset & 0xFF), 0x0f, 0x00, 0x5f, 0x01])
    }

    static func activityHistoryComplete(_ packets: [Data]) -> Bool {
        guard let header = packets.first, header.count >= 3 else { return false }
        let count = Int(header[header.startIndex + 2])
        return packets.count >= count + 1
    }

    private static func bcdToInt(_ byte: UInt8) -> Int { Int(byte >> 4) * 10 + Int(byte & 0x0F) }

    static func parseActivityHistory(_ packets: [Data], calendar: Calendar) -> [ActivitySamplePoint] {
        guard let header = packets.first, header.count >= 2 else { return [] }
        let calorieScale = header[header.startIndex + 1] == 0xF0 ? 10 : 1
        return packets.dropFirst().compactMap { packet in
            let b = Array(packet)
            guard b.count >= 13 else { return nil }
            let year = 2000 + bcdToInt(b[1]); let month = bcdToInt(b[2]); let day = bcdToInt(b[3])
            let idx = Int(b[4])
            let calories = (Int(b[7]) | Int(b[8]) << 8) * calorieScale
            let steps = Int(b[9]) | Int(b[10]) << 8
            let dist = Int(b[11]) | Int(b[12]) << 8
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                                hour: idx / 4, minute: (idx % 4) * 15))
            else { return nil }
            return ActivitySamplePoint(date: date, steps: steps, calories: calories, distanceMeters: dist)
        }
    }
}
