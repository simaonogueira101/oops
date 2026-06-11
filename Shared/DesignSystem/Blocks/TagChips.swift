import SwiftUI

/// A wrap of selectable tag chips (journal / "what's going on").
struct TagChips: View {
    var tags: [String]
    @Binding var selected: Set<String>

    var body: some View {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(tags, id: \.self) { tag in
                let on = selected.contains(tag)
                Button {
                    if on { selected.remove(tag) } else { selected.insert(tag) }
                } label: {
                    Text(tag)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(on ? AppColor.accent.opacity(0.2) : AppColor.track, in: Capsule())
                        .foregroundStyle(on ? AppColor.accent : AppColor.label)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Minimal flow layout for chips — wraps to the next row when the proposed width runs out.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    TagChips(tags: MockHealthData().suggestedTags(), selected: .constant(["Caffeine", "Stress"]))
        .padding()
        .background(AppColor.background)
}
