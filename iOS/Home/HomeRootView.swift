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
    @State private var recorder = WorkoutRecorder()
    @State private var date = Date()
    @State private var tab = HomeTab.home
    @State private var sheet: HomeSheet?
    @State private var justUpdated = false

    enum HomeTab: Hashable { case home, sleep, recovery, strain, record }
    enum HomeSheet: Int, Identifiable { case profile, sync, record; var id: Int { rawValue } }

    /// Selecting the trailing "+" opens the record drawer instead of switching tabs.
    private var tabSelection: Binding<HomeTab> {
        Binding(
            get: { tab },
            set: { selected in
                if selected == .record { sheet = .record } else { tab = selected }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                profile: profile,
                date: $date,
                battery: manager?.batteryStatus,
                syncState: sync.state,
                onProfile: { sheet = .profile },
                onSync: { sheet = .sync }
            )

            if justUpdated {
                UpdatedBanner(build: BuildInfo.build) {
                    withAnimation { justUpdated = false }
                }
            }

            TabView(selection: tabSelection) {
                Tab("Home", systemImage: "circle.grid.2x2", value: HomeTab.home) {
                    OverviewView(metrics: .sample, date: $date, recorder: recorder)
                }
                Tab("Sleep", systemImage: "moon", value: HomeTab.sleep) {
                    SleepView()
                }
                Tab("Recovery", systemImage: "heart", value: HomeTab.recovery) {
                    RecoveryView()
                }
                Tab("Strain", systemImage: "bolt", value: HomeTab.strain) {
                    StrainView()
                }
                Tab("Record", systemImage: "plus", value: HomeTab.record, role: .search) {
                    // Never shown — selection is intercepted to open the drawer. Painted with
                    // the app background so the tab system's momentary render doesn't flash black.
                    AppColor.background.ignoresSafeArea()
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .tint(AppColor.accent)
        .task {
            sync.modelContext = modelContext
            recorder.modelContext = modelContext
            let lastSeen = UserDefaults.standard.integer(forKey: "lastSeenBuild")
            if BuildInfo.build > lastSeen, lastSeen > 0 {
                withAnimation { justUpdated = true }
            }
            UserDefaults.standard.set(BuildInfo.build, forKey: "lastSeenBuild")

            if manager == nil {
                let manager = RingManager(transport: RingTransportFactory.make(), modelContext: modelContext)
                self.manager = manager
                await manager.refreshBattery()
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .profile:
                ProfileView(profile: profile)
            case .sync:
                MacSyncView(sync: sync, onSyncNow: pushSync)
            case .record:
                RecordWorkoutForm(recorder: recorder)
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
