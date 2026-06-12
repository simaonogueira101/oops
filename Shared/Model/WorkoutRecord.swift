import Foundation
import SwiftData

/// A completed workout session, persisted locally (no CloudKit, by design) — written when the
/// user ends a recording and read live by Strain's workout history.
@Model
final class WorkoutRecord {
    var name: String
    var symbol: String
    var start: Date
    var duration: TimeInterval
    var activeCalories: Int
    var avgHR: Int

    init(name: String, symbol: String, start: Date, duration: TimeInterval,
         activeCalories: Int, avgHR: Int) {
        self.name = name
        self.symbol = symbol
        self.start = start
        self.duration = duration
        self.activeCalories = activeCalories
        self.avgHR = avgHR
    }
}
