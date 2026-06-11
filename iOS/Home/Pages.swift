import SwiftUI

/// The Mac-sync drawer (iOS-only — opened from the top-bar sync button): status, a sync
/// button, and a table of recent sync history.
struct MacSyncView: View {
    let sync: SyncCoordinator
    let onSyncNow: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.heroGlyph)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(sync.state == .sent ? .green : .blue)
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
                        if sync.log.isEmpty {
                            Text("No syncs yet").foregroundStyle(.secondary)
                        } else {
                            ForEach(sync.log) { entry in
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(entry.success ? .green : .red)
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
            .navigationTitle("Mac Sync")
            .navigationBarTitleDisplayMode(.inline)
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
