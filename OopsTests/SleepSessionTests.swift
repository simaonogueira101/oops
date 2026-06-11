import Testing
import Foundation
@testable import Oops

struct SleepSessionTests {
    private func date(_ h: Int, _ m: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 11, hour: h, minute: m))!
    }

    @Test func sumsDurationPerStage() {
        let session = SleepSession(intervals: [
            SleepStageInterval(stage: .light, start: date(0, 0), end: date(1, 0)),   // 60m
            SleepStageInterval(stage: .deep, start: date(1, 0), end: date(1, 30)),    // 30m
            SleepStageInterval(stage: .light, start: date(1, 30), end: date(2, 0)),   // 30m
            SleepStageInterval(stage: .awake, start: date(2, 0), end: date(2, 6))     // 6m
        ])
        #expect(session.duration(of: .light) == 90 * 60)
        #expect(session.duration(of: .deep) == 30 * 60)
        #expect(session.totalAsleep == 120 * 60)        // light+deep, excludes awake
        #expect(session.timeInBed == 126 * 60)          // all intervals
    }

    @Test func computesPercentages() {
        let session = SleepSession(intervals: [
            SleepStageInterval(stage: .light, start: date(0, 0), end: date(3, 0)),    // 180m
            SleepStageInterval(stage: .deep, start: date(3, 0), end: date(4, 0))      // 60m
        ])
        #expect(session.percentage(of: .light) == 75)
        #expect(session.percentage(of: .deep) == 25)
        #expect(session.percentage(of: .rem) == 0)
    }
}
