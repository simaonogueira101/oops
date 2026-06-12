import SwiftUI
import SwiftData

/// The Mac-sync drawer (iOS-only — opened from the top-bar sync button): status, a sync
/// button, and a persisted table of recent sync history.
struct MacSyncView: View {
    let sync: SyncCoordinator
    let onSyncNow: () -> Void

    @Query(sort: \SyncLogEntry.date, order: .reverse) private var log: [SyncLogEntry]

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .heroGlyphStyle()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(sync.state == .sent ? AppColor.positive : AppColor.accent)
                    .padding(.top, Spacing.lg)

                Text(title).font(.title2.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)

                Button(action: onSyncNow) {
                    Text("Sync to Mac").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(sync.state == .searching)
                .padding(.horizontal, Spacing.lg)

                List {
                    Section("History") {
                        if log.isEmpty {
                            Text("No syncs yet").foregroundStyle(.secondary)
                        } else {
                            ForEach(log) { entry in
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(entry.success ? AppColor.positive : AppColor.negative)
                                    Text(entry.detail)
                                    Spacer()
                                    Text(entry.date, format: .dateTime.hour().minute().second())
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            .drawerTitle("Mac Sync")
        }
    }

    private var title: String {
        switch sync.state {
        case .idle: return sync.lastSync == nil ? "Not synced yet" : "Up to date"
        case .searching: return "Finding your Mac…"
        case .sent: return "Synced ✓"
        case .failed: return "Mac not found"
        }
    }

    private var subtitle: String {
        switch sync.state {
        case .searching: return "Looking for the Oops Mac app on your Wi-Fi."
        case .failed: return "Make sure the Mac app is open and on the same Wi-Fi."
        default:
            return sync.lastSync.map { "Last synced \($0.formatted(.relative(presentation: .named)))." }
                ?? "Open Oops on your Mac, then tap Sync to Mac."
        }
    }
}
