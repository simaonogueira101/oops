// Full GATT enumeration + passive listen for the Colmi R09.
// Discovers ALL services/characteristics/descriptors (no filter), subscribes to every
// notifiable characteristic, and passively logs unsolicited traffic for ~25s — to find
// anything we haven't been probing. Run: swift tools/ring_gatt.swift

import Foundation
import CoreBluetooth

setvbuf(stdout, nil, _IONBF, 0)

let svcV1 = CBUUID(string: "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E")
let svcV2 = CBUUID(string: "de5bf728-d711-4e47-af26-65e3012a5dc7")
func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined(separator: " ") }

func props(_ p: CBCharacteristicProperties) -> String {
    var s: [String] = []
    if p.contains(.read) { s.append("read") }
    if p.contains(.write) { s.append("write") }
    if p.contains(.writeWithoutResponse) { s.append("writeNR") }
    if p.contains(.notify) { s.append("notify") }
    if p.contains(.indicate) { s.append("indicate") }
    return s.joined(separator: "|")
}

let start = Date()
func log(_ s: String) { print("\(String(format: "%6.2f", Date().timeIntervalSince(start)))  \(s)") }

final class D: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var c: CBCentralManager!
    var ring: CBPeripheral?
    var pendingChars = 0

    func centralManagerDidUpdateState(_ cm: CBCentralManager) {
        guard cm.state == .poweredOn else { log("state=\(cm.state.rawValue)"); return }
        let already = cm.retrieveConnectedPeripherals(withServices: [svcV1, svcV2])
        if let p = already.first(where: { ($0.name ?? "").uppercased().contains("R09") }) ?? already.first {
            log("connected ring \(p.name ?? "?") via retrieve"); ring = p; p.delegate = self; cm.connect(p); return
        }
        log("scanning…"); cm.scanForPeripherals(withServices: nil)
    }
    func centralManager(_ cm: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        guard ((p.name ?? "").uppercased().contains("R09")) else { return }
        log("found \(p.name ?? "?") adv=\(advertisementData)"); cm.stopScan(); ring = p; p.delegate = self; cm.connect(p)
    }
    func centralManager(_ cm: CBCentralManager, didConnect p: CBPeripheral) {
        log("connected — discovering ALL services"); p.discoverServices(nil)
    }
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] { log("SERVICE \(s.uuid)"); pendingChars += 1; p.discoverCharacteristics(nil, for: s) }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] {
            log("  CHAR \(ch.uuid)  [\(props(ch.properties))]")
            p.discoverDescriptors(for: ch)
            if ch.properties.contains(.read) { p.readValue(for: ch) }
            if ch.properties.contains(.notify) || ch.properties.contains(.indicate) { p.setNotifyValue(true, for: ch) }
        }
        pendingChars -= 1
        if pendingChars == 0 { log("--- all services discovered; passively listening 25s ---") }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverDescriptorsFor ch: CBCharacteristic, error: Error?) {
        for d in ch.descriptors ?? [] { log("    descr \(d.uuid) of \(ch.uuid)"); p.readValue(for: d) }
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        if let v = ch.value { log("◀ \(ch.uuid) (\(v.count)B): \(hex(v))") }
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor d: CBDescriptor, error: Error?) {
        log("◀ descr \(d.uuid) = \(String(describing: d.value))")
    }
}

let d = D()
d.c = CBCentralManager(delegate: d, queue: .main)
DispatchQueue.main.asyncAfter(deadline: .now() + 35) { log("done"); exit(0) }
RunLoop.main.run()
