import SwiftUI
import SwiftData

/// The Strain tab: day strain, the activity that drove it, heart-rate zones, and workouts.
struct StrainView: View {
    @State private var period: Period = .week
    @Query(sort: \WorkoutRecord.start, order: .reverse) private var workouts: [WorkoutRecord]
    private var metrics: DayMetrics { MockHealthData().dayMetrics }
    private var mock: MockHealthData { MockHealthData() }
    private var strainText: String { metrics.strain.formatted(.number.precision(.fractionLength(1))) }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                strainHero
                activityStats
                zonesCard
                workoutsCard
                trendsCard
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
    }

    private var strainHero: some View {
        Card(label: "Day strain", accent: AppColor.strain) {
            HStack(spacing: Spacing.lg) {
                ZStack {
                    RingChart(value: metrics.strainFraction, color: AppColor.strain)
                    VStack(spacing: 0) {
                        Text(strainText).font(.metricValue).foregroundStyle(AppColor.label).minimumScaleFactor(0.5)
                        Text("of 21").font(.caption2).foregroundStyle(AppColor.secondaryLabel)
                    }
                }
                .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("\(metrics.activeCalories) cal").font(.title3.weight(.semibold))
                    Text("\(metrics.steps) steps").font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
                }
            }
        }
    }

    private var activityStats: some View {
        Card(label: "Activity") {
            HStack {
                StatTile(label: "Steps", value: "\(metrics.steps)", accent: AppColor.strain)
                StatTile(label: "Distance", value: "6.8 km")
                StatTile(label: "Calories", value: "\(metrics.activeCalories)")
            }
        }
    }

    private var zonesCard: some View {
        Card(label: "Heart-rate zones", accessory: .chevron) {
            ZoneScale(zones: mock.hrZones())
        }
        .navigates(to: .hrZones)
    }

    private var workoutsCard: some View {
        Card(label: "Workouts", accessory: .chevron) {
            if workouts.isEmpty {
                Text("No workouts yet — tap + to record one.")
                    .font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(workouts.prefix(3)) { workout in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: workout.symbol).foregroundStyle(AppColor.strain).frame(width: 24)
                            Text(workout.name).font(.subheadline)
                            Spacer()
                            Text(workout.start, format: .dateTime.weekday().hour().minute())
                                .font(.caption).foregroundStyle(AppColor.secondaryLabel)
                            Text(hm(workout.duration)).font(.caption.weight(.semibold)).monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigates(to: .workouts)
    }

    private var trendsCard: some View {
        Card(label: "Strain trends") {
            VStack(spacing: Spacing.sm) {
                PeriodPicker(period: $period)
                BarSeriesChart(samples: mock.stepsSeries(days: 14), color: AppColor.strain)
            }
        }
    }

    private func hm(_ ti: TimeInterval) -> String {
        let minutes = Int(ti / 60)
        if minutes < 1 { return "\(Int(ti))s" }
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

#Preview {
    NavigationStack { StrainView() }
}
