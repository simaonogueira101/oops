import CoreBluetooth
import Foundation
import Testing
@testable import Oops

struct RingScanMatcherTests {
    @Test func matchesWhenAdvertisingOurServiceUUID() {
        #expect(RingScanMatcher.matches(name: nil, advertisedServiceUUIDs: [RingScanMatcher.serviceUUID]))
    }

    @Test func matchesColmiNamePrefixesCaseInsensitively() {
        #expect(RingScanMatcher.matches(name: "R09_AB12", advertisedServiceUUIDs: []))
        #expect(RingScanMatcher.matches(name: "Colmi R09", advertisedServiceUUIDs: []))
        #expect(RingScanMatcher.matches(name: "colmi r09", advertisedServiceUUIDs: []))
    }

    @Test func ignoresUnrelatedDevices() {
        #expect(!RingScanMatcher.matches(name: "AirPods Pro", advertisedServiceUUIDs: []))
        #expect(!RingScanMatcher.matches(name: nil, advertisedServiceUUIDs: []))
        #expect(!RingScanMatcher.matches(
            name: "Some Watch",
            advertisedServiceUUIDs: [CBUUID(string: "180D")]
        ))
    }

    @Test func boundRingOnlyMatchesItsIdentifier() {
        let bound = UUID(); let other = UUID()
        #expect(RingScanMatcher.matches(name: "R09_4301", advertisedServiceUUIDs: [], boundID: bound, peripheralID: bound))
        #expect(!RingScanMatcher.matches(name: "R09_4301", advertisedServiceUUIDs: [], boundID: bound, peripheralID: other))
        #expect(RingScanMatcher.matches(name: "R09_4301", advertisedServiceUUIDs: [], boundID: nil, peripheralID: other))
    }
}
