import Foundation
#if os(iOS)
import UIKit
#endif

/// One battery reading on the wire (decoupled from the SwiftData @Model).
struct BatteryDTO: Codable, Equatable, Sendable {
    var timestamp: Date
    var level: Int
    var isCharging: Bool
}

/// What the iPhone pushes to the Mac.
struct SyncPayload: Codable, Equatable, Sendable {
    var source: String
    var battery: [BatteryDTO]
    var latestLevel: Int? { battery.first?.level }
}

enum OopsSync {
    /// Bonjour service type advertised by the Mac and browsed by the iPhone.
    static let serviceType = "_oops._tcp"

    static func encode(_ payload: SyncPayload) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    static func decode(_ data: Data) -> SyncPayload? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SyncPayload.self, from: data)
    }

    static var deviceName: String {
        #if os(iOS)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Mac"
        #endif
    }
}
