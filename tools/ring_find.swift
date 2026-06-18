// Find-device test: send 0x50 (find-device) to the R09 several times with gaps,
// trying a couple of payload variants, to see if it vibrates. Run: swift tools/ring_find.swift

import Foundation
import CoreBluetooth
setvbuf(stdout, nil, _IONBF, 0)

let svcV1 = CBUUID(string: "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E")
let chWrite = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
let chNotify = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
let svcV2 = CBUUID(string: "de5bf728-d711-4e47-af26-65e3012a5dc7")
func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined(separator: " ") }
func mk(_ cmd: UInt8, _ p: [UInt8] = []) -> Data {
    var b = [UInt8](repeating: 0, count: 16); b[0] = cmd
    for (i, v) in p.prefix(14).enumerated() { b[1 + i] = v }
    b[15] = UInt8(b[0..<15].reduce(0) { $0 + Int($1) } & 0xFF); return Data(b)
}

// Try several find-device payload variants, 4s apart so each buzz is distinguishable.
let seq: [(String, Data)] = [
    ("0x50 01",        mk(0x50, [0x01])),
    ("0x50 (no arg)",  mk(0x50)),
    ("0x50 02",        mk(0x50, [0x02])),
    ("0x50 01 01",     mk(0x50, [0x01, 0x01])),
    ("0x50 FF",        mk(0x50, [0xFF])),
]
let start = Date()
func log(_ s: String) { print("\(String(format: "%6.2f", Date().timeIntervalSince(start)))  \(s)") }

final class D: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var c: CBCentralManager!; var ring: CBPeripheral?; var w: CBCharacteristic?; var i = 0
    func centralManagerDidUpdateState(_ cm: CBCentralManager) {
        guard cm.state == .poweredOn else { if cm.state == .unauthorized { log("BT unauthorized"); exit(2) }; return }
        let a = cm.retrieveConnectedPeripherals(withServices: [svcV1, svcV2])
        if let p = a.first(where: { ($0.name ?? "").uppercased().contains("R09") }) ?? a.first {
            log("connected \(p.name ?? "?")"); ring = p; p.delegate = self; cm.connect(p); return
        }
        log("scanning…"); cm.scanForPeripherals(withServices: nil)
    }
    func centralManager(_ cm: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        guard (p.name ?? "").uppercased().contains("R09") else { return }
        cm.stopScan(); ring = p; p.delegate = self; cm.connect(p)
    }
    func centralManager(_ cm: CBCentralManager, didConnect p: CBPeripheral) { p.discoverServices([svcV1]) }
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] { p.discoverCharacteristics([chWrite, chNotify], for: s) }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] {
            if ch.uuid == chWrite { w = ch }
            if ch.uuid == chNotify { p.setNotifyValue(true, for: ch) }
        }
    }
    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor ch: CBCharacteristic, error: Error?) {
        if i == 0 { next() }
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        if let v = ch.value { log("    ◀ \(hex(v))") }
    }
    func next() {
        guard i < seq.count, let p = ring, let w else {
            if i >= seq.count { log("✅ done — did you feel any buzz?"); DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exit(0) } }
            return
        }
        let (label, packet) = seq[i]; i += 1
        log("▶▶▶ FIRING find-device \(label) — WATCH/FEEL THE RING NOW")
        p.writeValue(packet, for: w, type: w.properties.contains(.write) ? .withResponse : .withoutResponse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in self?.next() }
    }
}
let d = D(); d.c = CBCentralManager(delegate: d, queue: .main)
DispatchQueue.main.asyncAfter(deadline: .now() + 45) { log("timeout"); exit(1) }
RunLoop.main.run()
