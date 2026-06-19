// Live heart-rate capture: start the measurement and listen ~30s for a non-zero BPM.
// Keep the ring snug on a finger. Run: swift tools/ring_hr.swift

import Foundation
import CoreBluetooth
setvbuf(stdout, nil, _IONBF, 0)

let svcV1 = CBUUID(string: "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E")
let chWrite = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
let chNotify = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
let svcV2 = CBUUID(string: "de5bf728-d711-4e47-af26-65e3012a5dc7")
func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined(separator: " ") }
func mk(_ c: UInt8, _ p: [UInt8] = []) -> Data {
    var b = [UInt8](repeating: 0, count: 16); b[0] = c
    for (i, v) in p.prefix(14).enumerated() { b[1 + i] = v }
    b[15] = UInt8(b[0..<15].reduce(0) { $0 + Int($1) } & 0xFF); return Data(b)
}
let start = Date()
func log(_ s: String) { print("\(String(format: "%5.1f", Date().timeIntervalSince(start)))  \(s)") }

final class D: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var c: CBCentralManager!; var ring: CBPeripheral?; var w: CBCharacteristic?; var best = 0
    func centralManagerDidUpdateState(_ cm: CBCentralManager) {
        guard cm.state == .poweredOn else { if cm.state == .unauthorized { log("BT unauthorized"); exit(2) }; return }
        let a = cm.retrieveConnectedPeripherals(withServices: [svcV1, svcV2])
        if let p = a.first(where: { ($0.name ?? "").uppercased().contains("R09") }) ?? a.first {
            log("connected \(p.name ?? "?")"); ring = p; p.delegate = self; cm.connect(p); return
        }
        cm.scanForPeripherals(withServices: nil)
    }
    func centralManager(_ cm: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        guard (p.name ?? "").uppercased().contains("R09") else { return }
        cm.stopScan(); ring = p; p.delegate = self; cm.connect(p)
    }
    let chNotifyV2 = CBUUID(string: "de5bf729-d711-4e47-af26-65e3012a5dc7")
    var started = false
    func centralManager(_ cm: CBCentralManager, didConnect p: CBPeripheral) { p.discoverServices([svcV1, svcV2]) }
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] { p.discoverCharacteristics(nil, for: s) }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] {
            if ch.uuid == chWrite { w = ch }
            if ch.uuid == chNotify { p.setNotifyValue(true, for: ch) }
            // TEST: also enable the V2 Big-Data notify (de5bf729), exactly like our app does.
            if ch.uuid == chNotifyV2 { log("enabling V2 notify (de5bf729) — like the app"); p.setNotifyValue(true, for: ch) }
        }
    }
    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor ch: CBCharacteristic, error: Error?) {
        guard let w, !started else { return }
        started = true
        log("▶ start HR (bare 69 01 00) with V1+V2 notify enabled — listening 30s…")
        p.writeValue(mk(0x69, [0x01, 0x00]), for: w, type: .withResponse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            p.writeValue(mk(0x6A, [0x01, 0x00, 0x00]), for: w, type: .withResponse)
            log("⏹ stop. Best non-zero BPM seen: \(self?.best ?? 0)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exit(0) }
        }
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard let v = ch.value, v.count >= 4 else { return }
        let b = Array(v)
        if b[0] == 0x69 {
            let bpm = Int(b[3])
            if bpm > 0 { best = max(best, bpm); log("❤️  BPM = \(bpm)   (\(hex(v)))") }
        } else { log("    ◀ \(hex(v))") }
    }
}
let d = D(); d.c = CBCentralManager(delegate: d, queue: .main)
DispatchQueue.main.asyncAfter(deadline: .now() + 45) { print("timeout"); exit(1) }
RunLoop.main.run()
