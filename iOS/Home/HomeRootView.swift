import SwiftUI
import SwiftData

/// iPhone root: a persistent top bar above the iOS 26 Liquid-Glass floating tab bar
/// (Overview · Sleep · Recovery · Strain). Top-bar elements open their own sheets.
struct HomeRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BatteryReading.timestamp, order: .reverse) private var readings: [BatteryReading]

    @State private var manager: RingManager?
    @State private var sync = SyncCoordinator()
    @State private var profile = ProfileStore()
    @State private var date = Date()
    @State private var tab = HomeTab.overview
    @State private var sheet: HomeSheet?

    enum HomeTab: Hashable { case overview, sleep, recovery, strain }
    enum HomeSheet: Int, Identifiable { case profile, battery, sync; var id: Int { rawValue } }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                profile: profile,
                date: $date,
                battery: manager?.batteryStatus,
                syncState: sync.state,
                onProfile: { sheet = .profile },
                onBattery: { sheet = .battery },
                onSync: { sheet = .sync }
            )

            TabView(selection: $tab) {
                Tab("Overview", systemImage: "square.grid.2x2", value: HomeTab.overview) {
                    OverviewView(metrics: .sample, battery: manager?.batteryStatus, lastSync: sync.lastSync)
                }
                Tab("Sleep", systemImage: "bed.double", value: HomeTab.sleep) { SleepView() }
                Tab("Recovery", systemImage: "heart", value: HomeTab.recovery) { RecoveryView() }
                Tab("Strain", systemImage: "flame", value: HomeTab.strain) { StrainView() }
            }
        }
        .task {
            if manager == nil {
                let manager = RingManager(transport: MockRingTransport(), modelContext: modelContext)
                self.manager = manager
                await manager.refreshBattery()
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .profile:
                ProfileView(profile: profile)
            case .battery:
                if let manager {
                    NavigationStack { BatteryScreen(manager: manager) }
                }
            case .sync:
                MacSyncView(state: sync.state, lastSync: sync.lastSync, onSyncNow: pushSync)
            }
        }
    }

    private func pushSync() {
        let dtos = readings.prefix(50).map {
            BatteryDTO(timestamp: $0.timestamp, level: $0.level, isCharging: $0.isCharging)
        }
        sync.push(Array(dtos))
    }
}
