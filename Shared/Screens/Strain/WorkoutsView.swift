import SwiftUI

struct WorkoutsView: View {
    var body: some View {
        ContentUnavailableView("Workouts", systemImage: "figure.run",
                               description: Text("Workout history arrives with the ring."))
            .inlineNavigationTitle("Workouts")
    }
}
