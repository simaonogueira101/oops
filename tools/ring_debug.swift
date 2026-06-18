// Standalone macOS BLE debug tool for the Colmi R09.
// Connects directly from the Mac (no iPhone), sends a sequence of commands with the
// CORRECT checksum (& 0xFF), and dumps every notify packet as hex with light decoding.
//
// Run:  swift tools/ring_debug.swift
// Requires the ring to be AWAKE and NOT connected to the phone (turn off the iPhone's
// Bluetooth or quit the Oops app first, since the ring talks to one central at a time).
// The first run may prompt Terminal for Bluetooth permission — click Allow.

import Foundation
import CoreBluetooth

setvbuf(stdout, nil, _IONBF, 0)   // unbuffered so output appears live when redirected

// V1 (16-byte command) service
let svcV1 = CBUUID(string: "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E")
let chWrite = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
let chNotify = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
// V2 Big-Data (temperature) service
let svcV2 = CBUUID(string: "de5bf728-d711-4e47-af26-65e3012a5dc7")
let chV2Write = CBUUID(string: "de5bf72a-d711-4e47-af26-65e3012a5dc7")
let chV2Notify = CBUUID(string: "de5bf729-d711-4e47-af26-65e3012a5dc7")

func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined(separator: " ") }

func makePacket(_ cmd: UInt8, _ payload: [UInt8] = []) -> Data {
    var b = [UInt8](repeating: 0, count: 16)
    b[0] = cmd
    for (i, v) in payload.prefix(14).enumerated() { b[1 + i] = v }
    b[15] = UInt8(b[0..<15].reduce(0) { $0 + Int($1) } & 0xFF)   // CORRECT: & 0xFF
    return Data(b)
}

func bcd(_ v: Int) -> UInt8 { UInt8((v / 10) * 16 + (v % 10)) }

func uint32LE(_ v: UInt32) -> [UInt8] {
    [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
}

var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
let now = Date()
let todayMidnightUTC = UInt32(utc.startOfDay(for: now).timeIntervalSince1970)

func setTimeCmd() -> Data {
    let c = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
    return makePacket(0x01, [bcd((c.year ?? 2000) - 2000), bcd(c.month ?? 1), bcd(c.day ?? 1),
                             bcd(c.hour ?? 0), bcd(c.minute ?? 0), bcd(c.second ?? 0), 0x01])
}

// FULL real-data verification: enable everything, then fetch every metric and dump responses.
let sequence: [(String, Data, Bool)] = [
    ("setTime(UTC)",        setTimeCmd(), false),
    ("enable HRlog 16",     makePacket(0x16, [0x02, 0x01, 0x05]), false),
    ("enable SpO2 2C",      makePacket(0x2C, [0x02, 0x01]), false),
    ("enable HRV 38",       makePacket(0x38, [0x02, 0x01]), false),
    ("enable stress 36",    makePacket(0x36, [0x02, 0x01]), false),
    ("enable temp 3A",      makePacket(0x3A, [0x03, 0x02, 0x01]), false),
    ("battery 03",          makePacket(0x03), false),
    // live HR — start, let it stream a few seconds (frames log automatically), then stop
    ("liveHR start 69",     makePacket(0x69, [0x01, 0x01]), false),
    ("(wait for stream)",   makePacket(0x03), false),
    ("(wait for stream)",   makePacket(0x03), false),
    ("(wait for stream)",   makePacket(0x03), false),
    ("liveHR stop 6A",      makePacket(0x6A, [0x01, 0x00, 0x00]), false),
    // V1 history fetches
    ("HR history 0x15",     makePacket(0x15, ts4()), false),
    ("steps 0x43 off0",     makePacket(0x43, [0x00, 0x0f, 0x00, 0x5f, 0x01]), false),
    ("stress 0x37",         makePacket(0x37, ts4()), false),
    ("HRV 0x39",            makePacket(0x39, ts4()), false),
    // Big-Data V2 fetches
    ("SpO2 V2 BC2A",        Data([0xBC, 0x2A, 0x01, 0x00, 0xFF, 0x00, 0xFF]), true),
    ("sleep V2 BC27",       Data([0xBC, 0x27, 0x01, 0x00, 0xFF, 0x00, 0xFF]), true),
    ("temp V2 BC25",        Data([0xBC, 0x25, 0x01, 0x00, 0x3E, 0x81, 0x02]), true),
]
func ts4() -> [UInt8] { uint32LE(todayMidnightUTC) }

final class Delegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var central: CBCentralManager!
    var ring: CBPeripheral?
    var w: CBCharacteristic?
    var n: CBCharacteristic?
    var v2w: CBCharacteristic?
    var v2n: CBCharacteristic?
    var step = 0
    var notifyReady = 0

    func log(_ s: String) { print("\(String(format: "%6.2f", Date().timeIntervalSince(start)))  \(s)") }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn:
            // The ring is often already connected at the macOS system level (shows in the Mac's
            // Bluetooth list). Scanning won't surface a connected peripheral — retrieve it.
            let already = c.retrieveConnectedPeripherals(withServices: [svcV1, svcV2])
            if let p = already.first(where: { ($0.name ?? "").uppercased().contains("R09")
                                              || ($0.name ?? "").uppercased().contains("COLMI") })
                ?? already.first {
                log("Found already-connected \(p.name ?? "?") via retrieveConnectedPeripherals — connecting")
                ring = p; p.delegate = self; c.connect(p); return
            }
            log("BT on — scanning…"); c.scanForPeripherals(withServices: nil)
        case .unauthorized: log("❌ Bluetooth NOT authorized for this process (TCC). Allow it for Terminal."); exit(2)
        case .poweredOff: log("❌ Bluetooth is OFF on the Mac."); exit(2)
        default: log("state=\(c.state.rawValue)")
        }
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? p.name
        guard let name, name.uppercased().contains("R09") || name.uppercased().contains("COLMI") else { return }
        log("Found \(name) rssi=\(RSSI) — connecting")
        c.stopScan(); ring = p; p.delegate = self; c.connect(p)
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        log("Connected — discovering services"); p.discoverServices([svcV1, svcV2])
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        log("❌ connect failed: \(error?.localizedDescription ?? "?")"); exit(2)
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] {
            log("service \(s.uuid)")
            p.discoverCharacteristics(nil, for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] {
            if ch.uuid == chWrite { w = ch }
            if ch.uuid == chNotify { n = ch; p.setNotifyValue(true, for: ch) }
            if ch.uuid == chV2Write { v2w = ch }
            if ch.uuid == chV2Notify { v2n = ch; p.setNotifyValue(true, for: ch) }
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor ch: CBCharacteristic, error: Error?) {
        if ch.uuid == chNotify || ch.uuid == chV2Notify {
            notifyReady += 1
            log("notify enabled on \(ch.uuid) (\(notifyReady))")
            if notifyReady == 1 { sendNext() }   // start once V1 notify is up
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard let v = ch.value else { return }
        let tag = ch.uuid == chV2Notify ? "V2◀" : "◀"
        log("\(tag) (\(v.count)B) \(hex(v))")
    }

    func sendNext() {
        guard step < sequence.count else {
            log("✅ sequence complete"); DispatchQueue.main.asyncAfter(deadline: .now() + 3) { exit(0) }
            return
        }
        let (label, packet, v2) = sequence[step]; step += 1
        guard let p = ring else { return }
        if v2 {
            guard let v2w else { log("(no V2 write char — skipping \(label))"); sendNext(); return }
            log("▶ \(label): \(hex(packet))")
            p.writeValue(packet, for: v2w, type: v2w.properties.contains(.write) ? .withResponse : .withoutResponse)
        } else {
            guard let w else { return }
            log("▶ \(label): \(hex(packet))")
            p.writeValue(packet, for: w, type: w.properties.contains(.write) ? .withResponse : .withoutResponse)
        }
        // space commands out so responses are attributable
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in self?.sendNext() }
    }
}

let start = Date()
let d = Delegate()
d.central = CBCentralManager(delegate: d, queue: .main)
// Overall timeout
DispatchQueue.main.asyncAfter(deadline: .now() + 90) { print("timeout"); exit(1) }
RunLoop.main.run()
