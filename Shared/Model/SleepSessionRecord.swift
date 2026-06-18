import Foundation
import SwiftData

@Model final class SleepSessionRecord {
    var dayStart: Date
    @Relationship(deleteRule: .cascade) var intervals: [SleepStageIntervalRecord]
    init(dayStart: Date, intervals: [SleepStageIntervalRecord]) { self.dayStart = dayStart; self.intervals = intervals }
}

@Model final class SleepStageIntervalRecord {
    var stageRaw: Int; var start: Date; var end: Date
    init(stageRaw: Int, start: Date, end: Date) { self.stageRaw = stageRaw; self.start = start; self.end = end }
}
