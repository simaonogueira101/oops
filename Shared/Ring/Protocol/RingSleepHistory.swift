import Foundation

extension RingProtocol {
    static func sleepHistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x44, payload: uint32LE(utcMidnightUnix(for: day, calendar: calendar)))
    }

    static func sleepHistoryComplete(_ packets: [Data]) -> Bool {
        guard let header = packets.first(where: { $0.count > 2 && $0[$0.startIndex + 1] == 0 }) else { return false }
        return packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }.count >= Int(header[header.startIndex + 2])
    }

    private static func sleepStage(for code: UInt8) -> SleepStage? {
        switch code { case 1: return .light; case 2: return .deep; case 3: return .rem; case 4: return .awake; default: return nil }
    }

    static func parseSleep(_ packets: [Data], dayStart: Date) -> [SleepStageInterval] {
        let data = packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }
        var cursor = dayStart
        var intervals: [SleepStageInterval] = []
        for packet in data {
            let b = Array(packet)
            var i = 2
            while i + 1 < min(15, b.count) {   // values live in bytes[2..14]; byte[15] is the checksum
                let code = b[i]; let minutes = Int(b[i + 1]); i += 2
                if minutes == 0 { continue }
                let end = cursor.addingTimeInterval(Double(minutes) * 60)
                // Always advance the cursor to keep the timeline aligned, even for unknown stages.
                if let stage = sleepStage(for: code) {
                    intervals.append(SleepStageInterval(stage: stage, start: cursor, end: end))
                }
                cursor = end
            }
        }
        return intervals
    }
}
