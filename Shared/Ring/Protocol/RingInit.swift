import Foundation

/// The bind/init handshake the official QRing app runs after connecting, captured byte-for-byte
/// over PacketLogger. Replicating it fully is what makes the ring grant the fast BLE connection
/// interval (an iOS central can't set the interval itself) and serve V1 history reliably.
extension RingProtocol {
    /// `04 01 1a` — phone-OS / app-info (01 = iOS).
    static func phoneInfoCommand() -> Data { makePacket(command: 0x04, payload: [0x01, 0x1A]) }

    /// `0a 01` — get-config sub-1.
    static func getConfig1Command() -> Data { makePacket(command: 0x0A, payload: [0x01]) }

    /// `0a 02 …` — get-config sub-2 (carries the app/id blob the official app sends verbatim).
    static func getConfig2Command() -> Data {
        makePacket(command: 0x0A, payload: [0x02, 0x00, 0x00, 0x00, 0x1F, 0xAF, 0x41, 0x69, 0x4B, 0xA0])
    }

    /// `19 01 01 01` — set prefs (units/format).
    static func setPrefsCommand() -> Data { makePacket(command: 0x19, payload: [0x01, 0x01, 0x01]) }

    /// `16 01 02` — enable HR monitoring (matches the capture, vs our older `16 02 01 05`).
    static func enableHRMonitorCommand() -> Data { makePacket(command: 0x16, payload: [0x01, 0x02]) }
    /// `2c 01` — enable auto SpO2.
    static func enableSpO2MonitorCommand() -> Data { makePacket(command: 0x2C, payload: [0x01]) }
    /// `36 01` — enable stress monitoring.
    static func enableStressMonitorCommand() -> Data { makePacket(command: 0x36, payload: [0x01]) }
    /// `38 01 02` — enable HRV monitoring.
    static func enableHRVMonitorCommand() -> Data { makePacket(command: 0x38, payload: [0x01, 0x02]) }
    /// `21 01` — goals/steps query.
    static func goalsQueryCommand() -> Data { makePacket(command: 0x21, payload: [0x01]) }
    /// `3b 01 01` — enable (skin-temp / wear) monitoring.
    static func enable3BCommand() -> Data { makePacket(command: 0x3B, payload: [0x01, 0x01]) }
    /// `3a 03 01` — enable all-day temperature (matches the capture, vs our older `3a 03 02 01`).
    static func enableTempMonitorCommand() -> Data { makePacket(command: 0x3A, payload: [0x03, 0x01]) }
}
