import Foundation
import SwiftData

/// A persisted battery reading. Local-only SwiftData (no CloudKit, by design).
@Model
final class BatteryReading {
    var timestamp: Date
    var level: Int
    var isCharging: Bool

    init(timestamp: Date, level: Int, isCharging: Bool) {
        self.timestamp = timestamp
        self.level = level
        self.isCharging = isCharging
    }
}
