import Foundation

/// The single place that decides which `RingTransport` the app talks to (the spec's
/// "composition root").
///
/// Default rule: the Simulator (and anywhere without real BLE) uses the mock; a physical
/// device uses CoreBluetooth — *but only once the ring exists*. The R09 hasn't arrived yet,
/// so `ringAvailable` is `false` and the app uses the mock everywhere, keeping it fully
/// usable without hardware. Flip `ringAvailable` to `true` when the ring is in hand to
/// activate the real path on devices. `forceMock` is the manual override for exercising the
/// mock on a device even after the ring exists.
enum RingTransportFactory {
    /// Set to `true` once the physical R09 is available for on-device BLE.
    static let ringAvailable = true

    @MainActor
    static func make(forceMock: Bool = false) -> any RingTransport {
        #if targetEnvironment(simulator)
        return MockRingTransport()
        #else
        return (ringAvailable && !forceMock) ? BLERingTransport() : MockRingTransport()
        #endif
    }
}
