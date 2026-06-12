import SwiftUI

/// The persistent top bar as floating Liquid Glass elements over the transparent nav:
/// avatar (opens Profile), a split day navigator (‹ · date · ›, the date taps to today), and
/// the battery + Mac glyph pill (opens Mac sync).
struct TopBar: View {
    let profile: ProfileStore
    @Binding var date: Date
    let battery: BatteryStatus?
    let syncState: SyncState
    let onProfile: () -> Void
    let onSync: () -> Void

    /// All elements match the avatar pill: 28pt avatar + xxs padding each side.
    private var pillHeight: CGFloat { 28 + Spacing.xxs * 2 }

    var body: some View {
        GlassEffectContainer(spacing: Spacing.xxs) {
            ZStack {
                DateNav(date: $date, pillHeight: pillHeight)

                HStack {
                    Button(action: onProfile) {
                        Avatar(profile: profile, size: 28)
                            .padding(Spacing.xxs)
                    }
                    .buttonStyle(.plain)
                    .frame(height: pillHeight)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Profile")

                    Spacer()

                    Button(action: onSync) {
                        HStack(spacing: Spacing.sm) {
                            batteryLabel
                            Image(systemName: "laptopcomputer")
                                .imageScale(.small)
                                .foregroundStyle(syncState == .sent ? AppColor.positive : .primary)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .frame(height: pillHeight)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityLabel("Ring battery and Mac sync")
                    .accessibilityHint("Opens Mac sync")
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    private var batteryLabel: some View {
        HStack(spacing: Spacing.xxs) {
            if let battery {
                Text("\(battery.level)%").font(.caption.weight(.medium)).monospacedDigit()
            }
            Image(systemName: batterySymbol)
                .imageScale(.small)
                .foregroundStyle(battery?.isCharging == true ? AppColor.positive : .primary)
        }
        .accessibilityLabel(batteryAccessibilityLabel)
    }

    private var batterySymbol: String {
        guard let status = battery else { return "battery.50percent" }
        if status.isCharging { return "battery.100percent.bolt" }
        switch status.level {
        case ...10: return "battery.0percent"
        case ...30: return "battery.25percent"
        case ...60: return "battery.50percent"
        case ...85: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var batteryAccessibilityLabel: String {
        guard let status = battery else { return "Ring battery" }
        return "Ring battery \(status.level) percent\(status.isCharging ? ", charging" : "")"
    }
}

/// ‹ · date · › as three separate glass buttons: the arrows step a day (within the last two
/// weeks, capped at today); tapping the date jumps back to today.
private struct DateNav: View {
    @Binding var date: Date
    let pillHeight: CGFloat

    private var cal: Calendar { .current }
    private var today: Date { cal.startOfDay(for: .now) }
    private var earliest: Date { cal.date(byAdding: .day, value: -13, to: today)! }
    private var isToday: Bool { cal.isDateInToday(date) }
    private var atEarliest: Bool { cal.startOfDay(for: date) <= earliest }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.backward")
                    .imageScale(.small)
                    .frame(width: pillHeight, height: pillHeight)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .disabled(atEarliest)
            .accessibilityLabel("Previous day")

            Button { withAnimation(.snappy) { date = today } } label: {
                Text(label)
                    .font(.caption.weight(.medium)).monospacedDigit()
                    .frame(minWidth: 44)
                    .padding(.horizontal, Spacing.xs)
                    .frame(height: pillHeight)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel(isToday ? "Today" : label)
            .accessibilityHint("Go to today")

            Button { step(1) } label: {
                Image(systemName: "chevron.forward")
                    .imageScale(.small)
                    .frame(width: pillHeight, height: pillHeight)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .disabled(isToday)
            .accessibilityLabel("Next day")
        }
        .foregroundStyle(.primary)
    }

    private var label: String {
        isToday ? "Today" : date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    private func step(_ days: Int) {
        guard let next = cal.date(byAdding: .day, value: days, to: date) else { return }
        let clamped = min(max(cal.startOfDay(for: next), earliest), today)
        withAnimation(.snappy) { date = clamped }
    }
}
