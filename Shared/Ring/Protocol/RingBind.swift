import Foundation

extension RingProtocol {
    /// `0x10` (CMD_BIND_SUCCESS): registers this phone as the ring's bound host. The official
    /// app sends this once after connecting during its "bind a device" ceremony (the UI's
    /// Bind/Unbind). Many oudmon-family rings gate real-time streaming (live HR) and history
    /// logging (sleep/HRV) on having been bound, so we send it at the start of every session —
    /// it's idempotent and fire-and-forget (the ring doesn't reply). Payload is all-zero, so the
    /// packet is `10 00 … 00 10` (checksum 0x10).
    static func bindSuccessCommand() -> Data { makePacket(command: 0x10, payload: []) }

    /// `0x3C` (CMD_DEVICE_FUNCTION_SUPPORT): query the ring's capability bitfield. The official
    /// app sends this during init; the ring appears to enter its "full client / real-time
    /// capable" state once queried — which is the state in which it requests the fast BLE
    /// connection interval that live-HR streaming needs (iOS can't set the interval itself).
    static func deviceSupportCommand() -> Data { makePacket(command: 0x3C, payload: []) }
}
