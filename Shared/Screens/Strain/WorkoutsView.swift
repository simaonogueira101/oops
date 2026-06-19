import SwiftUI
import SwiftData

/// Recorded-workout history (live from the local store); each row pushes a summary.
struct WorkoutsView: View {
    @Query(sort: \WorkoutRecord.start, order: .reverse) private var workouts: [WorkoutRecord]

    var body: some View {
        Group {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "figure.run",
                    description: Text("Tap + on the tab bar to record one.")
                )
            } else {
                List(workouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: workout.symbol)
                                .foregroundStyle(AppColor.strain)
                                .frame(width: 36, height: 36)
                                .background(AppColor.strain.opacity(0.15),
                                            in: RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(workout.name).font(.headline)
                                Text(workout.start.formatted(.dateTime.weekday().day().month().hour().minute()))
                                    .font(.caption).foregroundStyle(AppColor.secondaryLabel)
                            }
                            Spacer()
                            Text(workout.duration.formattedDuration)
                                .font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .background(AppColor.background)
        .drawerTitle("Workouts")
    }
}

/// A recorded workout's summary: stats and a heart-rate trace. (No map — the ring has no GPS.)
struct WorkoutDetailView: View {
    let workout: WorkoutRecord

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Card(label: workout.name, title: workout.start.formatted(.dateTime.weekday(.wide).day().month())) {
                    HStack {
                        StatTile(label: "Duration", value: workout.duration.formattedDuration)
                        StatTile(label: "Calories", value: "\(workout.activeCalories)", unit: "cal")
                        StatTile(label: "Avg HR", value: "\(workout.avgHR)", unit: "bpm")
                    }
                }
                Card(label: "Heart rate") {
                    BarSeriesChart(
                        samples: [], period: .today,
                        color: AppColor.strain, baseline: Double(workout.avgHR),
                        xDomain: workout.start...workout.start.addingTimeInterval(max(60, workout.duration)))
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .drawerTitle(workout.name)
    }
}

#Preview {
    NavigationStack { WorkoutsView() }
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}
