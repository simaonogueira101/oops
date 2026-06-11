import SwiftUI
import SwiftData

/// iPhone root: the shared battery screen plus a "Sync to Mac" bar (iOS-only).
struct iOSRootView: View {
    @Query(sort: \BatteryReading.timestamp, order: .reverse) private var readings: [BatteryReading]
    @State private var sync = SyncCoordinator()

    var body: some View {
        ContentView()
            .safeAreaInset(edge: .bottom) { syncBar }
    }

    private var syncBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Sync to Mac").font(.subheadline.weight(.medium))
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                let dtos = readings.prefix(50).map {
                    BatteryDTO(timestamp: $0.timestamp, level: $0.level, isCharging: $0.isCharging)
                }
                sync.push(Array(dtos))
            } label: {
                Image(systemName: sync.state == .sent ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(sync.state == .sent ? .green : .blue)
            }
            .disabled(readings.isEmpty || sync.state == .searching)
        }
        .padding(12)
        .background(.bar)
    }

    private var statusText: String {
        switch sync.state {
        case .idle: return readings.isEmpty ? "No readings yet" : "\(readings.count) reading\(readings.count == 1 ? "" : "s") ready"
        case .searching: return "Finding your Mac on Wi-Fi…"
        case .sent: return "Synced ✓"
        case .failed: return "Mac not found — is it on the same Wi-Fi?"
        }
    }
}
