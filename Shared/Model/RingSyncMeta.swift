import Foundation
import SwiftData

@Model final class RingSyncMeta {
    var boundRingID: String?
    var boundRingName: String?
    /// Keyed by metric name ("hr","activity","sleep","stress","spo2","temperature") -> last synced day-start.
    var lastSyncedDay: [String: Date]
    init(boundRingID: String? = nil, boundRingName: String? = nil, lastSyncedDay: [String: Date] = [:]) {
        self.boundRingID = boundRingID; self.boundRingName = boundRingName; self.lastSyncedDay = lastSyncedDay
    }
}
