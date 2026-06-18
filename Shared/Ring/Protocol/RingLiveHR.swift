import Foundation

extension RingProtocol {
    /// `0x69`: start a real-time measurement. Payload [type, action]; type 1 = heart rate.
    static func liveHRStartCommand() -> Data { makePacket(command: 0x69, payload: [0x01, 0x01]) }

    /// `0x6A`: stop the real-time measurement.
    static func liveHRStopCommand() -> Data { makePacket(command: 0x6A, payload: [0x01, 0x00]) }

    /// Response [0x69, type, error, value]; BPM in byte[3] when byte[2]==0.
    static func parseLiveHR(_ data: Data) -> Int? {
        guard data.count >= 4 else { return nil }
        let b = Array(data)
        guard b[0] == 0x69, b[2] == 0 else { return nil }
        let bpm = Int(b[3])
        return bpm > 0 ? bpm : nil
    }
}
