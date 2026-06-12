import SwiftUI

extension View {
    /// Present a bottom drawer (sheet) from a tapped card. Glanceable medium detent first,
    /// expandable to full — with the system's sheet material and chrome (no overrides).
    func cardDrawer<DrawerContent: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> DrawerContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .presentationDetents(detents)
                .presentationDragIndicator(detents.count > 1 ? .visible : .automatic)
        }
    }
}

/// A card whose content discloses extra detail in place (Oura "Heart & stress" accordion).
struct ExpandableCard<Collapsed: View, Detail: View>: View {
    private let label: String?
    private let accent: Color?
    private let collapsed: () -> Collapsed
    private let detail: () -> Detail
    @State private var expanded = false

    init(label: String? = nil,
         accent: Color? = nil,
         @ViewBuilder collapsed: @escaping () -> Collapsed,
         @ViewBuilder detail: @escaping () -> Detail) {
        self.label = label
        self.accent = accent
        self.collapsed = collapsed
        self.detail = detail
    }

    var body: some View {
        Card(label: label, accent: accent,
             accessory: .icon(expanded ? "chevron.up" : "chevron.down")) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                collapsed()
                if expanded {
                    detail()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.snappy) { expanded.toggle() } }
    }
}

#Preview {
    ScrollView {
        ExpandableCard(label: "Sleeping HR", accent: AppColor.recovery) {
            Text("46–62 bpm").font(.title3.weight(.semibold))
        } detail: {
            Text("Your sleeping heart rate dips as you recover overnight.")
                .font(.footnote).foregroundStyle(AppColor.secondaryLabel)
        }
        .padding(Spacing.md)
    }
    .background(AppColor.background)
}
