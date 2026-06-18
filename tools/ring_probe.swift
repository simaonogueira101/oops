// Curated, SAFE opcode probe for the Colmi R09. Sends a hand-picked list of read/fetch/enable
// commands and logs every response — to discover capabilities we don't use yet (esp. HRV 0x39).
// EXPLICITLY SKIPS destructive opcodes: 0x08 (power off), 0xFF (factory reset), and all writes
// that change persistent settings (phone name 0x04, goals 0x21, notifications 0x73).
// Run: swift tools/ring_probe.swift

import Foundation
import CoreBluetooth
setvbuf(stdout, nil, _IONBF, 0)

let svcV1 = CBUUID(string: "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E")
let chWrite = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
let chNotify = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
let svcV2 = CBUUID(string: "de5bf728-d711-4e47-af26-65e3012a5dc7")
let chV2Write = CBUUID(string: "de5bf72a-d711-4e47-af26-65e3012a5dc7")
let chV2Notify = CBUUID(string: "de5bf729-d711-4e47-af26-65e3012a5dc7")
func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined(separator: " ") }
func mk(_ cmd: UInt8, _ p: [UInt8] = []) -> Data {
    var b = [UInt8](repeating: 0, count: 16); b[0] = cmd
    for (i, v) in p.prefix(14).enumerated() { b[1 + i] = v }
    b[15] = UInt8(b[0..<15].reduce(0) { $0 + Int($1) } & 0xFF); return Data(b)
}
var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
let mid = UInt32(utc.startOfDay(for: Date()).timeIntervalSince1970)
let ts: [UInt8] = [UInt8(mid & 0xFF), UInt8((mid >> 8) & 0xFF), UInt8((mid >> 16) & 0xFF), UInt8((mid >> 24) & 0xFF)]

// (label, packet, v2) — SAFE only.
let seq: [(String, Data, Bool)] = [
    ("battery 0x03 (control)",  mk(0x03), false),
    ("prefs read 0A 01",        mk(0x0A, [0x01]), false),
    ("HR-log read 16 01",       mk(0x16, [0x01]), false),
    ("SpO2 pref read 2C 01",    mk(0x2C, [0x01]), false),
    ("stress pref read 36 01",  mk(0x36, [0x01]), false),
    ("HRV pref read 38 01",     mk(0x38, [0x01]), false),
    ("enable HRV 38 02 01",     mk(0x38, [0x02, 0x01]), false),
    ("HRV sync 0x39 (ts)",      mk(0x39, ts), false),
    ("HRV sync 0x39 (no arg)",  mk(0x39), false),
    ("stress sync 0x37 (ts)",   mk(0x37, ts), false),
    ("packet-size 2F 01",       mk(0x2F, [0x01]), false),
    ("find-device 0x50 (vibrate)", mk(0x50, [0x01]), false),
    // unknown but plausibly-read opcodes (skip 0x08 power-off / 0xFF reset)
    ("probe 0x09",              mk(0x09), false),
    ("probe 0x0B",              mk(0x0B), false),
    ("probe 0x17",              mk(0x17), false),
    ("probe 0x22",              mk(0x22), false),
    ("probe 0x42 (sync?)",      mk(0x42, [0x01]), false),
    // V2 big-data re-check (did data accumulate?) + HRV-as-bigdata guess
    ("V2 SpO2 BC2A",            Data([0xBC, 0x2A, 0x01, 0x00, 0xFF, 0x00, 0xFF]), true),
    ("V2 sleep BC27",           Data([0xBC, 0x27, 0x01, 0x00, 0xFF, 0x00, 0xFF]), true),
    ("V2 temp BC25",            Data([0xBC, 0x25, 0x01, 0x00, 0x3E, 0x81, 0x02]), true),
    ("V2 HRV BC36?",            Data([0xBC, 0x36, 0x01, 0x00, 0xFF, 0x00, 0xFF]), true),
    ("V2 activity BC24?",       Data([0xBC, 0x24, 0x01, 0x00, 0xFF, 0x00, 0xFF]), true),
]

let start = Date()
func log(_ s: String) { print("\(String(format: "%6.2f", Date().timeIntervalSince(start)))  \(s)") }

final class D: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var c: CBCentralManager!; var ring: CBPeripheral?; var w, n, v2w, v2n: CBCharacteristic?
    var i = 0; var ready = 0; var lastLabel = ""
    func centralManagerDidUpdateState(_ cm: CBCentralManager) {
        guard cm.state == .poweredOn else { log("BT state=\(cm.state.rawValue)"); if cm.state == .unauthorized { exit(2) }; return }
        let a = cm.retrieveConnectedPeripherals(withServices: [svcV1, svcV2])
        if let p = a.first(where: { ($0.name ?? "").uppercased().contains("R09") }) ?? a.first {
            log("connected \(p.name ?? "?") via retrieve"); ring = p; p.delegate = self; cm.connect(p); return
        }
        log("scanning…"); cm.scanForPeripherals(withServices: nil)
    }
    func centralManager(_ cm: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        guard (p.name ?? "").uppercased().contains("R09") else { return }
        cm.stopScan(); ring = p; p.delegate = self; cm.connect(p)
    }
    func centralManager(_ cm: CBCentralManager, didConnect p: CBPeripheral) { p.discoverServices([svcV1, svcV2]) }
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] { p.discoverCharacteristics(nil, for: s) }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] {
            if ch.uuid == chWrite { w = ch }; if ch.uuid == chNotify { n = ch; p.setNotifyValue(true, for: ch) }
            if ch.uuid == chV2Write { v2w = ch }; if ch.uuid == chV2Notify { v2n = ch; p.setNotifyValue(true, for: ch) }
        }
    }
    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor ch: CBCharacteristic, error: Error?) {
        ready += 1; if ready == 1 { next() }
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard let v = ch.value else { return }
        log("    ◀\(ch.uuid == chV2Notify ? "V2" : "") \(hex(v))")
    }
    func next() {
        guard i < seq.count else { log("✅ done"); DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exit(0) }; return }
        let (label, packet, v2) = seq[i]; i += 1; lastLabel = label
        guard let p = ring else { return }
        if v2 { guard let v2w else { next(); return }; log("▶ \(label): \(hex(packet))"); p.writeValue(packet, for: v2w, type: .withoutResponse) }
        else  { guard let w else { return };       log("▶ \(label): \(hex(packet))"); p.writeValue(packet, for: w, type: w.properties.contains(.write) ? .withResponse : .withoutResponse) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in self?.next() }
    }
}
let d = D(); d.c = CBCentralManager(delegate: d, queue: .main)
DispatchQueue.main.asyncAfter(deadline: .now() + 70) { print("timeout"); exit(1) }
RunLoop.main.run()
