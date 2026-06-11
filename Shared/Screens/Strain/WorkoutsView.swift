import SwiftUI

/// A list of workouts; each row pushes a detail with a map, summary, and HR chart.
struct WorkoutsView: View {
    private var workouts: [Workout] { MockHealthData().workouts() }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        Card(accent: AppColor.strain, accessory: .chevron) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: workout.symbol)
                                    .foregroundStyle(AppColor.strain)
                                    .frame(width: 36, height: 36)
                                    .background(AppColor.strain.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(workout.name).font(.headline)
                                    Text(workout.start.formatted(.dateTime.weekday().hour().minute()))
                                        .font(.caption).foregroundStyle(AppColor.secondaryLabel)
                                }
                                Spacer()
                                Text(hm(workout.duration)).font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .inlineNavigationTitle("Workouts")
    }

    private func hm(_ ti: TimeInterval) -> String {
        let minutes = Int(ti / 60)
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// A single workout's detail: route map, summary stats, and a heart-rate trace.
struct WorkoutDetailView: View {
    let workout: Workout
    private var mock: MockHealthData { MockHealthData() }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Card(label: workout.name) { WorkoutMapSnapshot() }
                Card(label: "Summary") {
                    HStack {
                        StatTile(label: "Duration", value: hm(workout.duration), accent: AppColor.strain)
                        StatTile(label: "Calories", value: "\(workout.activeCalories)")
                        StatTile(label: "Avg HR", value: "\(workout.avgHR)")
                    }
                }
                Card(label: "Heart rate") {
                    LineTrendChart(samples: mock.series(days: 20, base: Double(workout.avgHR), spread: 30),
                                   color: AppColor.strain, baseline: Double(workout.avgHR))
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .inlineNavigationTitle(workout.name)
    }

    private func hm(_ ti: TimeInterval) -> String {
        let minutes = Int(ti / 60)
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

#Preview {
    NavigationStack { WorkoutsView() }
}
