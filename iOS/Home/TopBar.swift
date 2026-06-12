import SwiftUI

/// The persistent top bar as three floating Liquid Glass pills over the (transparent) nav:
/// avatar (left), a centered day navigator, and the ring battery + Mac-sync status (right).
struct TopBar: View {
    let profile: ProfileStore
    @Binding var date: Date
    let battery: BatteryStatus?
    let syncState: SyncState
    let onProfile: () -> Void
    let onSync: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: Spacing.xxs) {
            ZStack {
                DateNav(date: $date)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xs)
                    .glassEffect(.regular.interactive(), in: .capsule)

                HStack {
                    Button(action: onProfile) {
                        Avatar(profile: profile, size: 28)
                            .padding(Spacing.xxs)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Profile")

                    Spacer()

                    HStack(spacing: Spacing.sm) {
                        batteryLabel
                        Button(action: onSync) {
                            Image(systemName: "laptopcomputer")
                                .imageScale(.small)
                                .foregroundStyle(syncState == .sent ? AppColor.positive : .primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mac sync")
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .glassEffect(.regular.interactive(), in: .capsule)
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

/// ‹ date › — arrows step a day (within the last two weeks, capped at today), the centered
/// label taps back to today.
private struct DateNav: View {
    @Binding var date: Date

    private var cal: Calendar { .current }
    private var today: Date { cal.startOfDay(for: .now) }
    private var earliest: Date { cal.date(byAdding: .day, value: -13, to: today)! }
    private var isToday: Bool { cal.isDateInToday(date) }
    private var atEarliest: Bool { cal.startOfDay(for: date) <= earliest }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Button { step(-1) } label: { Image(systemName: "chevron.backward").imageScale(.small) }
                .disabled(atEarliest)
                .accessibilityLabel("Previous day")
            Button { date = today } label: {
                Text(label).font(.caption.weight(.medium)).monospacedDigit().frame(minWidth: 44)
            }
            .accessibilityLabel(isToday ? "Today" : label)
            .accessibilityHint("Go to today")
            Button { step(1) } label: { Image(systemName: "chevron.forward").imageScale(.small) }
                .disabled(isToday)
                .accessibilityLabel("Next day")
        }
        .buttonStyle(.plain)
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
