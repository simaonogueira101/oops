import Testing
import Foundation
@testable import Oops

struct MockHealthDataTests {
    @Test func isDeterministic() {
        let a = MockHealthData(seed: 42)
        let b = MockHealthData(seed: 42)
        #expect(a.hrvSeries(days: 7).map(\.value) == b.hrvSeries(days: 7).map(\.value))
        #expect(a.sleepSession().intervals.count == b.sleepSession().intervals.count)
    }

    @Test func sleepSessionIsContiguousAndOrdered() {
        let s = MockHealthData(seed: 1).sleepSession()
        for pair in zip(s.intervals, s.intervals.dropFirst()) {
            #expect(pair.0.end == pair.1.start)   // contiguous
        }
        #expect(s.totalAsleep > 0)
    }
}
