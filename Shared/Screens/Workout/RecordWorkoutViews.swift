import SwiftUI

/// The "+" drawer: pick a workout type, start recording.
struct RecordWorkoutForm: View {
    let recorder: WorkoutRecorder
    @Environment(\.dismiss) private var dismiss
    @State private var selected: WorkoutType = .run

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    ForEach(WorkoutType.allCases) { type in
                        Button {
                            selected = type
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: type.symbol)
                                    .foregroundStyle(AppColor.strain)
                                    .frame(width: 28)
                                Text(type.rawValue).foregroundStyle(AppColor.label)
                                Spacer()
                                if type == selected {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColor.accent)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button {
                        recorder.start(selected)
                        dismiss()
                    } label: {
                        Text("Start Workout")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppColor.strain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
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
                        Text(elapsedText(at: context.date, since: active.startDate))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .contentTransition(.numericText())
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
                            Text(elapsedText(at: context.date, since: active.startDate))
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

    var body: some View {
        if let active = recorder.active {
            TimelineView(.periodic(from: active.startDate, by: 1)) { context in
                VStack(spacing: Spacing.lg) {
                    Image(systemName: active.type.symbol)
                        .font(.headerGlyph)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppColor.strain)
                    Text(active.type.rawValue).font(.title2.weight(.semibold))
                    Text(elapsedText(at: context.date, since: active.startDate))
                        .font(.metricValue).monospacedDigit()
                        .contentTransition(.numericText())

                    HStack(spacing: Spacing.lg) {
                        StatTile(label: "Heart rate",
                                 value: "\(workoutLiveHR(elapsed: context.date.timeIntervalSince(active.startDate)))",
                                 unit: "bpm")
                        StatTile(label: "Calories",
                                 value: "\(workoutLiveCalories(elapsed: context.date.timeIntervalSince(active.startDate)))",
                                 unit: "cal")
                    }
                    .padding(.horizontal, Spacing.lg)

                    Button(role: .destructive) {
                        recorder.end()
                        dismiss()
                    } label: {
                        Text("End Workout").font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, Spacing.lg)

                    Spacer()
                }
                .padding(.top, Spacing.lg)
            }
        }
    }
}

private func elapsedText(at now: Date, since start: Date) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    let (h, m, s) = (seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

#Preview("Form") {
    RecordWorkoutForm(recorder: WorkoutRecorder())
}

#Preview("Banner") {
    let recorder = WorkoutRecorder()
    let _ = recorder.start(.run)
    return ActiveWorkoutBanner(recorder: recorder).padding().background(AppColor.background)
}
