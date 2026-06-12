import SwiftUI

/// The persistent top bar above the tab bar: avatar (left); ring battery, Mac sync, and the
/// record "+" (right). The day/date lives in each page's header, not here.
struct TopBar: View {
    let profile: ProfileStore
    let battery: BatteryStatus?
    let syncState: SyncState
    let onProfile: () -> Void
    let onBattery: () -> Void
    let onSync: () -> Void
    let onRecord: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button(action: onProfile) { Avatar(profile: profile, size: 30) }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile")

            Spacer()

            Button(action: onBattery) {
                HStack(spacing: Spacing.xxs) {
                    if let battery {
                        Text("\(battery.level)%").font(.caption.weight(.medium)).monospacedDigit()
                    }
                    Image(systemName: batterySymbol)
                        .foregroundStyle(battery?.isCharging == true ? AppColor.positive : .primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(batteryAccessibilityLabel)

            Button(action: onSync) {
                Image(systemName: "laptopcomputer")
                    .foregroundStyle(syncState == .sent ? AppColor.positive : .primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mac sync")

            Button(action: onRecord) {
                Image(systemName: "plus.circle.fill").imageScale(.large)
            }
            .accessibilityLabel("Record workout")
        }
        .tint(AppColor.accent)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
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
