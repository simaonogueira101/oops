import SwiftUI

/// The Journal: tag what's going on, log a mood, add a note. Mock-only (no persistence yet).
struct JournalView: View {
    @State private var selected: Set<String> = []
    @State private var mood = 2
    @State private var note = ""

    private let moods = ["cloud.rain.fill", "cloud.fill", "cloud.sun.fill", "sun.max.fill", "sparkles"]
    private let moodLabels = ["Rough", "Low", "Okay", "Good", "Great"]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Card(label: "What's going on?") {
                    TagChips(tags: MockHealthData().suggestedTags(), selected: $selected)
                }
                Card(label: "How do you feel?") {
                    VStack(spacing: Spacing.sm) {
                        HStack {
                            ForEach(moods.indices, id: \.self) { index in
                                Button { mood = index } label: {
                                    Image(systemName: moods[index])
                                        .font(.title2)
                                        .foregroundStyle(index == mood ? AppColor.accent : AppColor.secondaryLabel)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(moodLabels[mood]).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
                    }
                }
                Card(label: "Note") {
                    TextField("Add a comment", text: $note, axis: .vertical).lineLimit(3...6)
                }
                Card(accent: AppColor.accent, footer: .cta(title: "Save entry", action: {})) {
                    EmptyView()
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .inlineNavigationTitle("Journal")
    }
}

#Preview {
    NavigationStack { JournalView() }
}
