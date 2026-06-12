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
                PageHeader(title: "Strain")
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
                        Text(strainText)
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppColor.label)
                            .minimumScaleFactor(0.5)
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
                StatTile(label: "Steps", value: metrics.steps.formatted(.number))
                StatTile(label: "Distance", value: "6.8", unit: "km")
                StatTile(label: "Calories", value: "\(metrics.activeCalories)", unit: "cal")
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
                            Text(workout.duration.formattedDuration).font(.caption.weight(.semibold)).monospacedDigit()
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
                BarSeriesChart(samples: mock.stepsSeries(days: period.days), color: AppColor.strain)
                    .animation(.snappy, value: period)
            }
        }
    }

}

#Preview {
    NavigationStack { StrainView() }
}
