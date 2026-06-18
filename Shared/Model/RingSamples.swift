import Foundation
import SwiftData

@Model final class HeartRateSample {
    var timestamp: Date; var bpm: Int
    init(timestamp: Date, bpm: Int) { self.timestamp = timestamp; self.bpm = bpm }
}

@Model final class ActivitySample {
    var timestamp: Date; var steps: Int; var calories: Int; var distanceMeters: Int
    init(timestamp: Date, steps: Int, calories: Int, distanceMeters: Int) {
        self.timestamp = timestamp; self.steps = steps; self.calories = calories; self.distanceMeters = distanceMeters
    }
}

@Model final class SpO2Sample {
    var timestamp: Date; var percent: Int
    init(timestamp: Date, percent: Int) { self.timestamp = timestamp; self.percent = percent }
}

@Model final class StressSample {
    var timestamp: Date; var value: Int
    init(timestamp: Date, value: Int) { self.timestamp = timestamp; self.value = value }
}

@Model final class TemperatureSample {
    var timestamp: Date; var celsius: Double
    init(timestamp: Date, celsius: Double) { self.timestamp = timestamp; self.celsius = celsius }
}
