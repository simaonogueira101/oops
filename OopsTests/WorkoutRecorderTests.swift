import Testing
import Foundation
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

    @Test func everyTypeHasSymbol() {
        for type in WorkoutType.allCases {
            #expect(!type.symbol.isEmpty)
        }
    }
}
