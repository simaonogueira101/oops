import Foundation
import Testing
@testable import Oops

struct SyncPayloadTests {
    @Test func roundTripsSensorSamples() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dayStart = Date(timeIntervalSince1970: 1_699_900_000)
        let payload = SyncPayload(
            source: "iPhone",
            battery: [BatteryDTO(timestamp: now, level: 72, isCharging: false)],
            heartRate: [HeartRateDTO(timestamp: now, bpm: 61)],
            hrv: [HRVDTO(timestamp: now, value: 48)],
            spo2: [SpO2DTO(timestamp: now, percent: 97)],
            stress: [StressDTO(timestamp: now, value: 30)],
            temperature: [TemperatureDTO(timestamp: now, celsius: 36.4)],
            activity: [ActivityDTO(timestamp: now, steps: 4200, calories: 180, distanceMeters: 3100)],
            sleep: [SleepSessionDTO(dayStart: dayStart, intervals: [
                SleepStageIntervalDTO(stageRaw: 2, start: dayStart, end: now)
            ])]
        )

        let data = try #require(OopsSync.encode(payload))
        let decoded = try #require(OopsSync.decode(data))

        #expect(decoded == payload)
        #expect(decoded.heartRate.first?.bpm == 61)
        #expect(decoded.sleep.first?.intervals.first?.stageRaw == 2)
    }

    @Test func decodesBatteryOnlyPayloadWithEmptySensors() throws {
        // Simulates an older build that only sent battery: sensor keys absent.
        let json = #"{"source":"old","battery":[{"timestamp":"2023-11-14T22:13:20Z","level":50,"isCharging":true}]}"#
        let data = try #require(json.data(using: .utf8))
        let decoded = try #require(OopsSync.decode(data))

        #expect(decoded.battery.count == 1)
        #expect(decoded.heartRate.isEmpty)
        #expect(decoded.sleep.isEmpty)
    }
}
