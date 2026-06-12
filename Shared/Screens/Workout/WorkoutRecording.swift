import Foundation
import Observation
import SwiftData

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

/// Tracks the one workout being recorded right now. Ending a workout persists a `WorkoutRecord`
/// into the injected SwiftData context (same local-only store as the other data). Live HR is
/// mocked until the ring streams it.
@MainActor
@Observable
final class WorkoutRecorder {
    struct ActiveWorkout: Equatable {
        let type: WorkoutType
        let startDate: Date
    }

    private(set) var active: ActiveWorkout?
    /// Injected by the composition root (like `SyncCoordinator.modelContext`).
    @ObservationIgnored var modelContext: ModelContext?

    var isRecording: Bool { active != nil }

    func start(_ type: WorkoutType, at date: Date = .now) {
        active = ActiveWorkout(type: type, startDate: date)
    }

    func end(at date: Date = .now) {
        defer { active = nil }
        guard let active, let modelContext else { return }
        let duration = max(0, date.timeIntervalSince(active.startDate))
        modelContext.insert(WorkoutRecord(
            name: active.type.rawValue,
            symbol: active.type.symbol,
            start: active.startDate,
            duration: duration,
            activeCalories: workoutLiveCalories(elapsed: duration),
            avgHR: workoutLiveHR(elapsed: duration / 2)
        ))
        try? modelContext.save()
    }
}

// MARK: Mock live stats (replaced by ring data later)

/// Gentle 105–125 bpm sweep so the live numbers move believably.
func workoutLiveHR(elapsed: TimeInterval) -> Int {
    105 + Int(20 * (sin(elapsed / 45) + 1) / 2)
}

/// ~6 cal/min, floored at 1 so even a brief workout records something.
func workoutLiveCalories(elapsed: TimeInterval) -> Int {
    max(1, Int(elapsed / 60 * 6))
}
