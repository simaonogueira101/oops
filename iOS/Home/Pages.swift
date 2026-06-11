import SwiftUI

/// The Mac-sync page (iOS-only — opened from the top-bar sync button). Depends on the
/// iOS sync client, so it stays in the iOS target.
struct MacSyncView: View {
    let state: SyncState
    let lastSync: Date?
    let onSyncNow: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Spacer()
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.heroGlyph)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(state == .sent ? .green : .blue)
                Text(title).font(.title2.weight(.semibold))
                Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
                Button(action: onSyncNow) {
                    Text("Sync to Mac").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state == .searching)
            }
            .padding(Spacing.lg)
            .navigationTitle("Mac Sync")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var title: String {
        switch state {
        case .idle: return lastSync == nil ? "Not synced yet" : "Up to date"
        case .searching: return "Finding your Mac…"
        case .sent: return "Synced ✓"
        case .failed: return "Mac not found"
        }
    }

    private var subtitle: String {
        switch state {
        case .searching: return "Looking for the Oops Mac app on your Wi-Fi."
        case .failed: return "Make sure the Mac app is open and on the same Wi-Fi."
        default:
            return lastSync.map { "Last synced \($0.formatted(.relative(presentation: .named)))." }
                ?? "Open Oops on your Mac, then tap Sync to Mac."
        }
    }
}
