import Foundation

extension RingProtocol {
    /// `0x16`: enable the ring's periodic heart-rate logging at `intervalMinutes`.
    /// Without this the ring stores no HR history (0x15 returns an error). Payload
    /// [subtype=2 (set), enabled=1, interval]. Sent once per sync; harmless to repeat.
    static func enableHeartRateLoggingCommand(intervalMinutes: UInt8 = 5) -> Data {
        makePacket(command: 0x16, payload: [0x02, 0x01, intervalMinutes])
    }
}
