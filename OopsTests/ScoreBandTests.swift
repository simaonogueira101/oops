import Testing
import SwiftUI
@testable import Oops

struct ScoreBandTests {
    @Test func mapsScoreToBand() {
        #expect(ScoreBand(score: 10) == .poor)
        #expect(ScoreBand(score: 45) == .fair)
        #expect(ScoreBand(score: 70) == .good)
        #expect(ScoreBand(score: 90) == .optimal)
    }

    @Test func clampsOutOfRange() {
        #expect(ScoreBand(score: -5) == .poor)
        #expect(ScoreBand(score: 999) == .optimal)
    }

    @Test func everyBandHasLabel() {
        for band in ScoreBand.allCases {
            #expect(!band.label.isEmpty)
        }
    }
}
