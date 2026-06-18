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

// MARK: - SpO2 (0x2A)

extension RingBigData {
    /// Big Data V2 request for all-day SpO2 history.
    static func spo2Request() -> Data { Data([0xBC, 0x2A, 0x01, 0x00, 0xFF, 0x00, 0xFF]) }

    /// Header [0xBC, 0x2A, len_lo, len_hi]; complete when the declared payload length is in hand.
    /// If len==0, complete immediately.
    static func spo2Complete(_ packets: [Data]) -> Bool {
        let all = packets.reduce(Data(), +)
        guard all.count >= 4, all[all.startIndex] == 0xBC, all[all.startIndex + 1] == 0x2A else { return false }
        let len = Int(all[all.startIndex + 2]) | Int(all[all.startIndex + 3]) << 8
        if len == 0 { return true }
        return all.count >= 4 + len
    }

    /// Parses V2 SpO2 packets into hourly `MetricSample` values.
    /// Layout after 4-byte header + 2 filler bytes: per-day blocks starting at index 6.
    /// Each block: [days_ago][24 × (min%, max%)] = 1 + 48 bytes.
    /// value = round((min + max) / 2.0); pair (0, 0) is skipped.
    static func parseSpO2(_ packets: [Data], today: Date, calendar: Calendar) -> [MetricSample] {
        let all = Array(packets.reduce(Data(), +))
        guard all.count > 6, all[0] == 0xBC, all[1] == 0x2A else { return [] }
        let todayStart = calendar.startOfDay(for: today)
        var samples: [MetricSample] = []
        let blockSize = 1 + 48   // days_ago + 24 pairs
        var i = 6
        while i + blockSize <= all.count {
            let daysAgo = Int(all[i])
            guard let dayStart = calendar.date(byAdding: .day, value: -daysAgo, to: todayStart) else { break }
            let pairsStart = i + 1
            for hour in 0..<24 {
                let lo = pairsStart + hour * 2
                guard lo + 1 < all.count else { break }
                let minV = Int(all[lo]); let maxV = Int(all[lo + 1])
                if minV == 0 && maxV == 0 { continue }
                let value = (Double(minV) + Double(maxV)) / 2.0
                let timestamp = dayStart.addingTimeInterval(Double(hour) * 3600)
                samples.append(MetricSample(date: timestamp, value: value.rounded()))
            }
            i += blockSize
        }
        return samples
    }
}

// MARK: - Sleep (0x27)

extension RingBigData {
    /// Big Data V2 request for all-day sleep history.
    static func sleepRequest() -> Data { Data([0xBC, 0x27, 0x01, 0x00, 0xFF, 0x00, 0xFF]) }

    /// Header [0xBC, 0x27, len_lo, len_hi]; complete when the declared payload length is in hand.
    /// If len==0, complete immediately.
    static func sleepComplete(_ packets: [Data]) -> Bool {
        let all = packets.reduce(Data(), +)
        guard all.count >= 4, all[all.startIndex] == 0xBC, all[all.startIndex + 1] == 0x27 else { return false }
        let len = Int(all[all.startIndex + 2]) | Int(all[all.startIndex + 3]) << 8
        if len == 0 { return true }
        return all.count >= 4 + len
    }

    /// Parses V2 sleep packets into `SleepStageInterval` values.
    /// // LAYOUT UNVERIFIED — confirm against a real night's data on device
    /// Layout after 4-byte header + 2 filler bytes: per-day blocks starting at index 6.
    /// Each block: [days_ago][(stageCode, durationMinutes)…]
    /// Stage codes: 02=light, 03=deep, 04=REM, 05=awake.
    /// Unknown stage codes advance the cursor but are not appended to the result.
    static func parseSleep(_ packets: [Data], today: Date, calendar: Calendar) -> [SleepStageInterval] {
        let all = Array(packets.reduce(Data(), +))
        guard all.count > 6, all[0] == 0xBC, all[1] == 0x27 else { return [] }
        let len = Int(all[2]) | Int(all[3]) << 8
        let dataEnd = min(4 + len, all.count)
        let todayStart = calendar.startOfDay(for: today)
        var intervals: [SleepStageInterval] = []
        var i = 6
        while i < dataEnd {
            guard i < all.count else { break }
            let daysAgo = Int(all[i]); i += 1
            guard let dayStart = calendar.date(byAdding: .day, value: -daysAgo, to: todayStart) else { break }
            var cursor = dayStart
            while i + 1 < dataEnd {
                let code = all[i]; let minutes = Int(all[i + 1]); i += 2
                if minutes == 0 { continue }
                let end = cursor.addingTimeInterval(Double(minutes) * 60)
                let stage: SleepStage?
                switch code {
                case 0x02: stage = .light
                case 0x03: stage = .deep
                case 0x04: stage = .rem
                case 0x05: stage = .awake
                default:   stage = nil
                }
                if let stage {
                    intervals.append(SleepStageInterval(stage: stage, start: cursor, end: end))
                }
                cursor = end
            }
        }
        return intervals
    }
}
