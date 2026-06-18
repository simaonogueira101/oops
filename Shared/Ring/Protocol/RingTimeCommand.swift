import Foundation

extension RingProtocol {
    /// `0x01`: set the ring clock. Payload is 7 BCD bytes in UTC:
    /// [year-2000, month, day, hour, minute, second, language(1=English)].
    static func setTimeCommand(date: Date, calendar: Calendar) -> Data {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let payload: [UInt8] = [
            bcd((c.year ?? 2000) - 2000), bcd(c.month ?? 1), bcd(c.day ?? 1),
            bcd(c.hour ?? 0), bcd(c.minute ?? 0), bcd(c.second ?? 0), 0x01
        ]
        return makePacket(command: 0x01, payload: payload)
    }
}
