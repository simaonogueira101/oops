import Testing
import Foundation
import SwiftData
@testable import Oops

@MainActor
struct WorkoutRecorderTests {
    @Test func startsIdle() {
        let recorder = WorkoutRecorder()
        #expect(!recorder.isRecording)
        #expect(recorder.active == nil)
    }

    @Test func startSetsActiveWorkout() {
        let recorder = WorkoutRecorder()
        let date = Date(timeIntervalSince1970: 1_000_000)
        recorder.start(.run, at: date)
        #expect(recorder.isRecording)
        #expect(recorder.active == WorkoutRecorder.ActiveWorkout(type: .run, startDate: date))
    }

    @Test func startReplacesOngoingWorkout() {
        let recorder = WorkoutRecorder()
        recorder.start(.run)
        recorder.start(.yoga)
        #expect(recorder.active?.type == .yoga)
    }

    @Test func endClearsActiveWorkout() {
        let recorder = WorkoutRecorder()
        recorder.start(.walk)
        recorder.end()
        #expect(!recorder.isRecording)
    }

    @Test func endPersistsWorkoutRecord() throws {
        let container = try ModelContainer(
            for: WorkoutRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let recorder = WorkoutRecorder()
        recorder.modelContext = ModelContext(container)

        let start = Date(timeIntervalSince1970: 1_000_000)
        recorder.start(.run, at: start)
        recorder.end(at: start.addingTimeInterval(1800))

        let records = try ModelContext(container).fetch(FetchDescriptor<WorkoutRecord>())
        #expect(records.count == 1)
        #expect(records.first?.name == "Run")
        #expect(records.first?.duration == 1800)
        #expect(records.first?.activeCalories ?? 0 > 0)
    }

    @Test func endWithoutContextStillClears() {
        let recorder = WorkoutRecorder()
        recorder.start(.ride)
        recorder.end()
        #expect(recorder.active == nil)
    }

    @Test func everyTypeHasSymbol() {
        for type in WorkoutType.allCases {
            #expect(!type.symbol.isEmpty)
        }
    }
}
