import SwiftUI

/// The persistent top bar: avatar (left), date toggle (centre), ring battery + Mac sync
/// (right). Each side element opens its own page. No system navigation bar.
struct TopBar: View {
    let profile: ProfileStore
    @Binding var date: Date
    let battery: BatteryStatus?
    let syncState: SyncState
    let onProfile: () -> Void
    let onSync: () -> Void

    var body: some View {
        ZStack {
            // Absolutely centred; the date label itself has a fixed width (below).
            DateSelector(date: $date)
            HStack {
                Button(action: onProfile) { Avatar(profile: profile, size: 30) }
                    .buttonStyle(.plain)
                Spacer()
                HStack(spacing: Spacing.md) {
                    batteryLabel
                    Button(action: onSync) { syncLabel }.buttonStyle(.plain)
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
            Image(systemName: "circle.dashed").imageScale(.small)
                .foregroundStyle(battery?.isCharging == true ? AppColor.positive : .primary)
        }
    }

    private var syncLabel: some View {
        Image(systemName: "laptopcomputer").imageScale(.small)
            .foregroundStyle(syncState == .sent ? AppColor.positive : .primary)
    }
}

/// Round avatar: photo if set, else initials, else an SF Symbol — like Apple Health.
struct Avatar: View {
    let profile: ProfileStore
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let data = profile.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if !profile.initials.isEmpty {
                Circle().fill(.tint.opacity(0.2))
                    .overlay(Text(profile.initials).font(.subheadline.weight(.semibold)).foregroundStyle(.tint))
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// ◀ Today ▶ — steps the selected day; forward is disabled on today.
struct DateSelector: View {
    @Binding var date: Date

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Text(label).font(.headline).lineLimit(1).frame(width: 110)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .disabled(Calendar.current.isDateInToday(date))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var label: String {
        Calendar.current.isDateInToday(date)
            ? "Today"
            : date.formatted(.dateTime.weekday(.abbreviated).month().day())
    }

    private func shift(_ days: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: days, to: date) { date = next }
    }
}
