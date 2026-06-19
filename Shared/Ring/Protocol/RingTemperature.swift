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

    // MARK: - CRC-16/MODBUS

    /// CRC-16/MODBUS over `data`. Returns 0xFFFF for empty input.
    static func crc16(_ data: [UInt8]) -> UInt16 {
        if data.isEmpty { return 0xFFFF }
        var crc: UInt16 = 0xFFFF
        for b in data {
            crc ^= UInt16(b)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1 }
        }
        return crc
    }

    /// `BC 30 00 00 FF FF` — the big-data handshake the official app sends right after bind,
    /// before any history/live read. Part of the init that puts the ring in its real-time state.
    static func handshakeRequest() -> Data { bigDataRequest(action: 0x30, payload: []) }
    /// Any single response packet completes the handshake.
    static func handshakeComplete(_ packets: [Data]) -> Bool { !packets.isEmpty }

    /// Builds a Big-Data V2 framed request:
    /// `[0xBC, action, len_lo, len_hi, crc_lo, crc_hi] + payload`
    /// where `len = payload.count` and `crc = CRC-16/MODBUS(payload)`.
    static func bigDataRequest(action: UInt8, payload: [UInt8]) -> Data {
        let len = payload.count
        let crc = crc16(payload)
        var bytes: [UInt8] = [0xBC, action, UInt8(len & 0xFF), UInt8(len >> 8),
                               UInt8(crc & 0xFF), UInt8(crc >> 8)]
        bytes.append(contentsOf: payload)
        return Data(bytes)
    }

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
    /// Big Data V2 request for all-day SpO2 history. action=0x2A, payload=[0x02] →
    /// BC 2A 01 00 3E 81 02, matching the official QRing app (our earlier FF 00 FF was malformed).
    static func spo2Request() -> Data { bigDataRequest(action: 0x2A, payload: [0x02]) }

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
    /// action=0x27, payload=[0x01, 0x01] → BC 27 02 00 C1 E0 01 01. Payload [0x01, 0x01] matches
    /// the official QRing app on the wire (verified via PacketLogger); our earlier [0xFF, 0x01]
    /// got no response from the R09.
    static func sleepRequest() -> Data { bigDataRequest(action: 0x27, payload: [0x01, 0x01]) }

    /// Header [0xBC, 0x27, len_lo, len_hi, crc_lo, crc_hi]; complete when
    /// the concatenated bytes >= 6 + declared payload length.
    static func sleepComplete(_ packets: [Data]) -> Bool {
        let all = packets.reduce(Data(), +)
        guard all.count >= 6, all[all.startIndex] == 0xBC, all[all.startIndex + 1] == 0x27 else { return false }
        let len = Int(all[all.startIndex + 2]) | Int(all[all.startIndex + 3]) << 8
        if len == 0 { return true }
        return all.count >= 6 + len
    }

    /// Parses V2 sleep packets into `SleepStageInterval` values.
    ///
    /// Response layout: `[0xBC, 0x27, len_lo, len_hi, crc_lo, crc_hi]` header (6 bytes) + payload.
    /// - `response[6]` = data indicator: 0 → no sleep data.
    /// - Day blocks start at index 7. Each block:
    ///   - `[0]` dayOffset (days ago from today)
    ///   - `[1]` blockLenField; actual block size = blockLenField + 2
    ///   - `[2..3]` discarded
    ///   - `[4..5]` endMinutes LE (minutes since midnight of that day)
    ///   - `[6..]` (type, duration) pairs stride 2
    /// Stage codes: 2=light, 3=deep, 4=rem, 5=awake. 0/1 = no-data (advance cursor, skip interval).
    static func parseSleep(_ packets: [Data], today: Date, calendar: Calendar) -> [SleepStageInterval] {
        let all = Array(packets.reduce(Data(), +))
        guard all.count > 7, all[0] == 0xBC, all[1] == 0x27 else { return [] }
        // response[6] = data indicator; 0 means no sleep data
        guard all[6] != 0 else { return [] }
        let todayStart = calendar.startOfDay(for: today)
        var intervals: [SleepStageInterval] = []
        var blockStart = 7
        while blockStart < all.count {
            guard blockStart + 6 <= all.count else { break }
            let dayOffset = Int(all[blockStart])
            let blockLenField = Int(all[blockStart + 1])
            let blockLen = blockLenField + 2
            guard blockStart + blockLen <= all.count else { break }
            let block = Array(all[blockStart ..< blockStart + blockLen])
            // block[2..3] discarded
            let endMinutes = Int(block[4]) | (Int(block[5]) << 8)
            guard let dayMidnight = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else {
                blockStart += blockLen; continue
            }
            let endTime = dayMidnight.addingTimeInterval(Double(endMinutes) * 60)
            // Compute total duration to find startTime
            var total = 0
            var p = 6
            while p + 1 < block.count {
                total += Int(block[p + 1]); p += 2
            }
            let startTime = endTime.addingTimeInterval(-Double(total) * 60)
            var cursor = startTime
            p = 6
            while p + 1 < block.count {
                let type = block[p]
                let duration = Int(block[p + 1])
                p += 2
                let intervalEnd = cursor.addingTimeInterval(Double(duration) * 60)
                let stage: SleepStage?
                switch type {
                case 2: stage = .light
                case 3: stage = .deep
                case 4: stage = .rem
                case 5: stage = .awake
                default: stage = nil
                }
                if let stage {
                    intervals.append(SleepStageInterval(stage: stage, start: cursor, end: intervalEnd))
                }
                cursor = intervalEnd
            }
            blockStart += blockLen
        }
        return intervals
    }
}
