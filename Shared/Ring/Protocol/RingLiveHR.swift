import Foundation

extension RingProtocol {
    /// `0x69`: start a heart-rate measurement. Payload [type=1 (HR), sub=0]. Matches the
    /// official app's `StartHeartRateReq.getSimpleReq(1)`.
    static func liveHRStartCommand() -> Data { makePacket(command: 0x69, payload: [0x01, 0x00]) }

    /// `0x6A`: stop the measurement. Payload [type, 0, 0].
    static func liveHRStopCommand() -> Data { makePacket(command: 0x6A, payload: [0x01, 0x00, 0x00]) }

    /// `0x1E` (CMD_REAL_TIME_HEART_RATE) payload `0x03` (ACTION_CONTINUE): the keepalive the
    /// ring needs to keep streaming. Without it the sensor measures once and shuts off. The
    /// official app fires this on a repeating timer during a live read. (Note: the integer 3,
    /// NOT ASCII '3' = 0x33 — that earlier guess returned "unsupported".)
    static func liveHRKeepaliveCommand() -> Data { makePacket(command: 0x1E, payload: [0x03]) }

    /// Response [0x69, type, error, value]; BPM in byte[3] when byte[2]==0.
    static func parseLiveHR(_ data: Data) -> Int? {
        guard data.count >= 4 else { return nil }
        let b = Array(data)
        guard b[0] == 0x69, b[2] == 0 else { return nil }
        let bpm = Int(b[3])
        return bpm > 0 ? bpm : nil
    }
}
