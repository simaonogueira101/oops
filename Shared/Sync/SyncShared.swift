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

/// One sensor sample on the wire (each decoupled from its SwiftData @Model).
struct HeartRateDTO: Codable, Equatable, Sendable {
    var timestamp: Date
    var bpm: Int
}

struct HRVDTO: Codable, Equatable, Sendable {
    var timestamp: Date
    var value: Int
}

struct SpO2DTO: Codable, Equatable, Sendable {
    var timestamp: Date
    var percent: Int
}

struct StressDTO: Codable, Equatable, Sendable {
    var timestamp: Date
    var value: Int
}

struct TemperatureDTO: Codable, Equatable, Sendable {
    var timestamp: Date
    var celsius: Double
}

struct ActivityDTO: Codable, Equatable, Sendable {
    var timestamp: Date
    var steps: Int
    var calories: Int
    var distanceMeters: Int
}

struct SleepStageIntervalDTO: Codable, Equatable, Sendable {
    var stageRaw: Int
    var start: Date
    var end: Date
}

struct SleepSessionDTO: Codable, Equatable, Sendable {
    var dayStart: Date
    var intervals: [SleepStageIntervalDTO]
}

/// What the iPhone pushes to the Mac. Sensor arrays are additive and default to `[]`
/// so battery-only payloads from older builds still decode.
struct SyncPayload: Codable, Equatable, Sendable {
    var source: String
    var battery: [BatteryDTO]
    var heartRate: [HeartRateDTO] = []
    var hrv: [HRVDTO] = []
    var spo2: [SpO2DTO] = []
    var stress: [StressDTO] = []
    var temperature: [TemperatureDTO] = []
    var activity: [ActivityDTO] = []
    var sleep: [SleepSessionDTO] = []
    var latestLevel: Int? { battery.first?.level }

    init(
        source: String,
        battery: [BatteryDTO],
        heartRate: [HeartRateDTO] = [],
        hrv: [HRVDTO] = [],
        spo2: [SpO2DTO] = [],
        stress: [StressDTO] = [],
        temperature: [TemperatureDTO] = [],
        activity: [ActivityDTO] = [],
        sleep: [SleepSessionDTO] = []
    ) {
        self.source = source
        self.battery = battery
        self.heartRate = heartRate
        self.hrv = hrv
        self.spo2 = spo2
        self.stress = stress
        self.temperature = temperature
        self.activity = activity
        self.sleep = sleep
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decode(String.self, forKey: .source)
        battery = try c.decode([BatteryDTO].self, forKey: .battery)
        heartRate = try c.decodeIfPresent([HeartRateDTO].self, forKey: .heartRate) ?? []
        hrv = try c.decodeIfPresent([HRVDTO].self, forKey: .hrv) ?? []
        spo2 = try c.decodeIfPresent([SpO2DTO].self, forKey: .spo2) ?? []
        stress = try c.decodeIfPresent([StressDTO].self, forKey: .stress) ?? []
        temperature = try c.decodeIfPresent([TemperatureDTO].self, forKey: .temperature) ?? []
        activity = try c.decodeIfPresent([ActivityDTO].self, forKey: .activity) ?? []
        sleep = try c.decodeIfPresent([SleepSessionDTO].self, forKey: .sleep) ?? []
    }
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
