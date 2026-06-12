import SwiftUI

/// The "+" drawer: pick a workout type, start recording.
struct RecordWorkoutForm: View {
    let recorder: WorkoutRecorder
    @Environment(\.dismiss) private var dismiss
    @State private var selected: WorkoutType = .run

    var body: some View {
        NavigationStack {
            Form {
                Picker("Workout", selection: $selected) {
                    ForEach(WorkoutType.allCases) { type in
                        Label(type.rawValue, systemImage: type.symbol).tag(type)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .tint(AppColor.strain)
            .safeAreaInset(edge: .bottom) {
                Button {
                    recorder.start(selected)
                    dismiss()
                } label: {
                    Text("Start Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(AppColor.strain)
                .padding(Spacing.md)
            }
            .drawerTitle("Record Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Compact ongoing-workout bar for the iOS 26 tab-bar bottom accessory (Now-Playing style).
/// Tapping opens the live drawer.
struct ActiveWorkoutAccessory: View {
    let recorder: WorkoutRecorder
    @State private var showDrawer = false

    var body: some View {
        if let active = recorder.active {
            Button { showDrawer = true } label: {
                TimelineView(.periodic(from: active.startDate, by: 1)) { context in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "record.circle")
                            .symbolEffect(.pulse)
                            .foregroundStyle(AppColor.strain)
                        Text(active.type.rawValue).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(timerInterval: active.startDate...Date.distantFuture, countsDown: false)
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                        Text("\(workoutLiveHR(elapsed: context.date.timeIntervalSince(active.startDate))) bpm")
                            .font(.footnote).foregroundStyle(AppColor.secondaryLabel)
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Workout in progress: \(active.type.rawValue)")
            .cardDrawer(isPresented: $showDrawer, detents: [.medium, .large]) {
                ActiveWorkoutDrawer(recorder: recorder)
            }
        }
    }
}

/// The thin ongoing-workout banner shown in the macOS feed (no tab-bar accessory there).
/// Tapping opens the live drawer.
struct ActiveWorkoutBanner: View {
    let recorder: WorkoutRecorder
    @State private var showDrawer = false

    var body: some View {
        if let active = recorder.active {
            Button { showDrawer = true } label: {
                Card(accent: AppColor.strain, style: .tinted(AppColor.strain)) {
                    TimelineView(.periodic(from: active.startDate, by: 1)) { context in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "record.circle")
                                .symbolEffect(.pulse)
                                .foregroundStyle(AppColor.strain)
                            Text(active.type.rawValue).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(timerInterval: active.startDate...Date.distantFuture, countsDown: false)
                                .font(.subheadline.weight(.semibold)).monospacedDigit()
                            Text("\(workoutLiveHR(elapsed: context.date.timeIntervalSince(active.startDate))) bpm")
                                .font(.footnote).foregroundStyle(AppColor.secondaryLabel)
                        }
                    }
                }
            }
            .buttonStyle(CardLinkStyle())
            // The one drawer that stays half-height: glanceable live stats over the feed.
            .cardDrawer(isPresented: $showDrawer, detents: [.medium, .large]) {
                ActiveWorkoutDrawer(recorder: recorder)
            }
        }
    }
}

/// Live stats for the ongoing workout, plus the End button.
struct ActiveWorkoutDrawer: View {
    let recorder: WorkoutRecorder
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEnd = false

    var body: some View {
        if let active = recorder.active {
            TimelineView(.periodic(from: active.startDate, by: 1)) { context in
                VStack(spacing: Spacing.lg) {
                    Image(systemName: active.type.symbol)
                        .font(.headerGlyph)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppColor.strain)
                    Text(active.type.rawValue).font(.title2.weight(.semibold))
                    Text(timerInterval: active.startDate...Date.distantFuture, countsDown: false)
                        .metricValueStyle()

                    HStack(spacing: Spacing.lg) {
                        StatTile(label: "Heart rate",
                                 value: "\(workoutLiveHR(elapsed: context.date.timeIntervalSince(active.startDate)))",
                                 unit: "bpm")
                        StatTile(label: "Calories",
                                 value: "\(workoutLiveCalories(elapsed: context.date.timeIntervalSince(active.startDate)))",
                                 unit: "cal")
                    }
                    .padding(.horizontal, Spacing.lg)

                    Spacer()
                }
                .padding(.top, Spacing.lg)
            }
            .safeAreaInset(edge: .bottom) {
                Button(role: .destructive) {
                    confirmEnd = true
                } label: {
                    Text("End Workout").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(Spacing.md)
            }
            .confirmationDialog("End this workout?", isPresented: $confirmEnd, titleVisibility: .visible) {
                Button("End Workout", role: .destructive) {
                    recorder.end()
                    dismiss()
                }
                Button("Keep Going", role: .cancel) {}
            }
        }
    }
}

#Preview("Form") {
    RecordWorkoutForm(recorder: WorkoutRecorder())
}

#Preview("Banner") {
    let recorder = WorkoutRecorder()
    let _ = recorder.start(.run)
    return ActiveWorkoutBanner(recorder: recorder).padding().background(AppColor.background)
}
