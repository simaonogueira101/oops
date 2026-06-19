import Foundation

extension RingProtocol {
    /// `0x10` (CMD_BIND_SUCCESS): registers this phone as the ring's bound host. The official
    /// app sends this once after connecting during its "bind a device" ceremony (the UI's
    /// Bind/Unbind). Many oudmon-family rings gate real-time streaming (live HR) and history
    /// logging (sleep/HRV) on having been bound, so we send it at the start of every session —
    /// it's idempotent and fire-and-forget (the ring doesn't reply). Payload is all-zero, so the
    /// packet is `10 00 … 00 10` (checksum 0x10).
    static func bindSuccessCommand() -> Data { makePacket(command: 0x10, payload: []) }
}
