import Foundation
import SwiftUI

extension TimeInterval {
    /// "7 hr 32 min" / "45 sec" — Apple's duration vocabulary via Foundation format styles.
    var formattedDuration: String {
        Duration.seconds(self).formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
}

/// A single timestamped metric reading (used by trends, sparklines, charts).
struct MetricSample: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// Direction of a value relative to its baseline.
enum DeltaDirection {
    case up, down, flat

    var symbol: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .flat: return "minus"
        }
    }

    /// Up isn't always "good" (e.g. resting HR), so the caller states the polarity.
    func color(upIsGood: Bool = true) -> Color {
        switch self {
        case .flat: return AppColor.secondaryLabel
        case .up: return upIsGood ? AppColor.positive : AppColor.negative
        case .down: return upIsGood ? AppColor.negative : AppColor.positive
        }
    }
}

/// A value compared against a baseline (yesterday, 30-day average, …).
struct DeltaInfo: Equatable {
    let value: Double
    let baseline: Double

    var direction: DeltaDirection {
        if abs(value - baseline) < 0.0001 { return .flat }
        return value > baseline ? .up : .down
    }
}

/// The four sleep stages, top-to-bottom in the hypnogram.
enum SleepStage: String, CaseIterable, Identifiable {
    case awake, rem, light, deep
    var id: String { rawValue }

    var title: String { self == .rem ? "REM" : rawValue.capitalized }

    /// A single-hue intensity ramp of the sleep color (deeper = stronger); Awake uses the
    /// app-wide attention color. Keeps hue meaning unambiguous per tab.
    var color: Color {
        switch self {
        case .awake: return AppColor.caution
        case .rem:   return AppColor.sleep.opacity(0.45)
        case .light: return AppColor.sleep.opacity(0.7)
        case .deep:  return AppColor.sleep
        }
    }

    /// Vertical order in the hypnogram (Awake on top → Deep at the bottom).
    var row: Int {
        switch self {
        case .awake: return 0
        case .rem: return 1
        case .light: return 2
        case .deep: return 3
        }
    }
}

/// One contiguous stretch of a single sleep stage.
struct SleepStageInterval: Identifiable, Equatable {
    let id = UUID()
    let stage: SleepStage
    let start: Date
    let end: Date
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// A heart-rate zone bucket (time spent in a bpm band).
struct HRZone: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let lowerBPM: Int
    let upperBPM: Int
    let minutes: Int
    let color: Color
}

