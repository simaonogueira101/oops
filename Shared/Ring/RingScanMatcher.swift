import CoreBluetooth
import Foundation

/// Decides whether a discovered BLE advertisement is our Colmi R09 ring.
///
/// This is the one piece of the scan path that is pure logic, so it lives apart from the
/// CoreBluetooth delegate code (which can't run in the Simulator or CI) and is unit-tested.
///
/// The transport scans for *all* peripherals rather than filtering on the service UUID:
/// the R09 (verified on real hardware) advertises its name ("R09_4301") but NOT its GATT
/// service UUID, so a service-filtered scan finds nothing. We match either on the advertised
/// service UUID (in case a future unit advertises it) **or** on the ring's name fragment.
enum RingScanMatcher {
    /// Nordic-UART-style GATT service the ring is assumed to expose.
    /// Computed (not stored) because `CBUUID` isn't `Sendable`.
    static var serviceUUID: CBUUID { CBUUID(string: "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E") }

    /// Name fragments the Colmi R09 is known to advertise under.
    static let nameFragments = ["R09", "COLMI"]

    static func matches(name: String?, advertisedServiceUUIDs: [CBUUID]) -> Bool {
        if advertisedServiceUUIDs.contains(serviceUUID) { return true }
        if let name = name?.uppercased(), nameFragments.contains(where: name.contains) { return true }
        return false
    }
}
