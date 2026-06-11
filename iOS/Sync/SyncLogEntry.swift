import Foundation
import SwiftData

/// A persisted entry in the sync history (local-only SwiftData).
@Model
final class SyncLogEntry {
    var date: Date
    var detail: String
    var success: Bool

    init(date: Date, detail: String, success: Bool) {
        self.date = date
        self.detail = detail
        self.success = success
    }
}
