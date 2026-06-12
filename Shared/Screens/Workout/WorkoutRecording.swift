import Foundation
import Observation

/// The workout types a user can record from the "+" button.
enum WorkoutType: String, CaseIterable, Identifiable {
    case run = "Run"
    case walk = "Walk"
    case ride = "Ride"
    case strength = "Strength"
    case yoga = "Yoga"
    case hike = "Hike"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .ride: return "figure.outdoor.cycle"
        case .strength: return "dumbbell"
        case .yoga: return "figure.mind.and.body"
        case .hike: return "figure.hiking"
        }
    }
}

/// Tracks the one workout being recorded right now. UI-side only for now — when the ring
/// arrives this is where live HR lands; ending a workout will persist a `Workout`.
@MainActor
@Observable
final class WorkoutRecorder {
    struct ActiveWorkout: Equatable {
        let type: WorkoutType
        let startDate: Date
    }

    private(set) var active: ActiveWorkout?

    var isRecording: Bool { active != nil }

    func start(_ type: WorkoutType, at date: Date = .now) {
        active = ActiveWorkout(type: type, startDate: date)
    }

    func end() {
        active = nil
    }
}
