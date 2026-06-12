import SwiftUI

/// Trailing header accessory.
enum CardAccessory {
    case none, chevron
    case value(String)
    case delta(DeltaInfo, upIsGood: Bool)
    case icon(String)
    case toggle(String, Binding<Bool>)
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

/// The app's one card, styled like Apple Health's: borderless rounded rect on the grouped
/// background, sentence-case `Label` header (icon + name in the domain tint), content slot,
/// optional footer. Presentation only — routing is supplied by the consumer.
struct Card<Content: View>: View {
    var label: String?
    var systemImage: String?
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var hasHeaderAccessory: Bool {
        if case .none = accessory { return false }
        return true
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if let label {
                    Group {
                        if let systemImage {
                            Label(label, systemImage: systemImage)
                        } else {
                            Text(label)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent ?? AppColor.secondaryLabel)
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
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        case .value(let value):
            Text(value).font(.subheadline).foregroundStyle(AppColor.secondaryLabel)
        case .delta(let info, let upIsGood):
            DeltaLabel(info: info, upIsGood: upIsGood, tint: accent)
        case .icon(let name):
            Image(systemName: name).foregroundStyle(accent ?? AppColor.secondaryLabel)
        case .toggle(let title, let binding):
            Toggle(title, isOn: binding).labelsHidden()
        }
    }

    @ViewBuilder private var footerView: some View {
        switch footer {
        case .none:
            EmptyView()
        case .text(let string):
            Text(string).font(.footnote).foregroundStyle(AppColor.secondaryLabel)
        case .cta(let title, let action):
            Button(action: action) { Text(title).frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .tint(AppColor.accent)
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .plain:
            AppColor.surface
        case .tinted(let color):
            color.opacity(0.12)
        }
    }
}

#Preview("Card") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            Card(label: "Recovery", systemImage: "heart.fill", title: "Good",
                 accent: AppColor.recovery, accessory: .chevron) {
                Text("72").metricValueStyle().foregroundStyle(AppColor.label)
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
