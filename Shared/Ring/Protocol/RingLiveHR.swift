import Foundation

extension RingProtocol {
    /// `0x69`: start a real-time measurement. Payload [type, action]; type 1 = heart rate.
    static func liveHRStartCommand() -> Data { makePacket(command: 0x69, payload: [0x01, 0x01]) }

    /// `0x6A`: stop the real-time measurement. Payload [type, 0, 0].
    static func liveHRStopCommand() -> Data { makePacket(command: 0x6A, payload: [0x01, 0x00, 0x00]) }

    /// `0x1E` payload `0x33` ('3'): keepalive/continue. The ring emits one warm-up frame
    /// (value 0) then goes quiet unless poked with this repeatedly; it answers each keepalive
    /// with the current reading once the sensor locks on.
    static func liveHRKeepaliveCommand() -> Data { makePacket(command: 0x1E, payload: [0x33]) }

    /// Response [0x69, type, error, value]; BPM in byte[3] when byte[2]==0.
    static func parseLiveHR(_ data: Data) -> Int? {
        guard data.count >= 4 else { return nil }
        let b = Array(data)
        guard b[0] == 0x69, b[2] == 0 else { return nil }
        let bpm = Int(b[3])
        return bpm > 0 ? bpm : nil
    }
}
