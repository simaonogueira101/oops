import SwiftUI

/// Trailing header accessory.
enum CardAccessory {
    case none, chevron
    case value(String)
    case delta(DeltaInfo, upIsGood: Bool)
    case icon(String)
    case toggle(Binding<Bool>)
}

/// Card surface treatment.
enum CardStyle {
    case plain
    case tinted(Color)
}

/// Optional footer below the content slot.
enum CardFooter {
    case text(String)
    case cta(title: String, action: () -> Void)
}

/// The app's one card. Header (label/title/accessory) + a content slot + optional footer, on a
/// rounded surface. Presentation only — routing is supplied by the consumer (NavigationLink,
/// `.cardDrawer`, `ExpandableCard`). Use across every screen.
struct Card<Content: View>: View {
    var label: String?
    var title: String?
    var accent: Color?
    var accessory: CardAccessory = .none
    var style: CardStyle = .plain
    var footer: CardFooter?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if label != nil || title != nil || hasHeaderAccessory {
                header
            }
            content()
            footerView
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { background }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppColor.separator, lineWidth: 0.5)
        )
    }

    private var hasHeaderAccessory: Bool {
        if case .none = accessory { return false }
        return true
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if let label {
                    Text(label.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent ?? AppColor.secondaryLabel)
                        .tracking(0.8)
                }
                if let title {
                    Text(title).font(.headline)
                }
            }
            Spacer(minLength: Spacing.xs)
            accessoryView
        }
    }

    @ViewBuilder private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        case .value(let value):
            Text(value).font(.headline).foregroundStyle(AppColor.secondaryLabel)
        case .delta(let info, let upIsGood):
            DeltaLabel(info: info, upIsGood: upIsGood)
        case .icon(let name):
            Image(systemName: name).foregroundStyle(accent ?? AppColor.secondaryLabel)
        case .toggle(let binding):
            Toggle("", isOn: binding).labelsHidden()
        }
    }

    @ViewBuilder private var footerView: some View {
        switch footer {
        case .none:
            EmptyView()
        case .text(let string):
            Divider().overlay(AppColor.separator)
            Text(string).font(.footnote).foregroundStyle(AppColor.secondaryLabel)
        case .cta(let title, let action):
            Button(action: action) { Text(title).frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.regular)
                .tint(accent ?? AppColor.accent)
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .plain:
            AppColor.surface
        case .tinted(let color):
            LinearGradient(colors: [color.opacity(0.18), AppColor.surface],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

#Preview("Card") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            Card(label: "Recovery", title: "Good to go", accent: AppColor.recovery,
                 accessory: .chevron, footer: .text("Higher than yesterday.")) {
                Text("72").font(.metricValue).foregroundStyle(AppColor.recovery)
            }
            Card(label: "HRV", accent: AppColor.recovery,
                 accessory: .delta(DeltaInfo(value: 48, baseline: 44), upIsGood: true)) {
                Text("48 ms").font(.title.weight(.semibold))
            }
            Card(label: "New in Oops", accent: AppColor.sleep, style: .tinted(AppColor.sleep),
                 footer: .cta(title: "Get started", action: {})) {
                Text("Track daytime stress in real time").font(.headline)
            }
        }
        .padding(Spacing.md)
    }
    .background(AppColor.background)
}
