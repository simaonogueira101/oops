import SwiftUI

/// The persistent top bar as three floating Liquid Glass pills, each a single button tappable
/// across its whole surface: avatar → Profile, date → back to today (day changes are swipes on
/// the views), battery + Mac glyph → Mac sync.
struct TopBar: View {
    let profile: ProfileStore
    @Binding var date: Date
    let battery: BatteryStatus?
    let syncState: SyncState
    let onProfile: () -> Void
    let onSync: () -> Void

    /// All pills match the avatar pill: 28pt avatar + xxs padding each side.
    private var pillHeight: CGFloat { 28 + Spacing.xxs * 2 }

    var body: some View {
        GlassEffectContainer(spacing: Spacing.xxs) {
            ZStack {
                datePill

                HStack {
                    profilePill
                    Spacer()
                    syncPill
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    // MARK: Pills

    private var profilePill: some View {
        Button(action: onProfile) {
            Avatar(profile: profile, size: 28)
                .padding(Spacing.xxs)
                .frame(height: pillHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Profile")
    }

    private var datePill: some View {
        Button { withAnimation(.snappy) { date = Calendar.current.startOfDay(for: .now) } } label: {
            Text(dateLabel)
                .font(.caption.weight(.medium)).monospacedDigit()
                .frame(minWidth: 64)
                .padding(.horizontal, Spacing.sm)
                .frame(height: pillHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(dateLabel)
        .accessibilityHint("Go to today")
    }

    private var syncPill: some View {
        Button(action: onSync) {
            HStack(spacing: Spacing.sm) {
                if let battery {
                    Text("\(battery.level)%").font(.caption.weight(.medium)).monospacedDigit()
                }
                Image(systemName: batterySymbol)
                    .imageScale(.small)
                    .foregroundStyle(battery?.isCharging == true ? AppColor.positive : .primary)
                Image(systemName: "laptopcomputer")
                    .imageScale(.small)
                    .foregroundStyle(syncState == .sent ? AppColor.positive : .primary)
            }
            .padding(.horizontal, Spacing.sm)
            .frame(height: pillHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(batteryAccessibilityLabel)
        .accessibilityHint("Opens Mac sync")
    }

    // MARK: Derived

    private var dateLabel: String {
        Calendar.current.isDateInToday(date)
            ? "Today"
            : date.formatted(.dateTime.weekday(.abbreviated).day())
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
