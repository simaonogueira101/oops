import SwiftUI
import SwiftData

/// iPhone root: the `TabView` is the root (so the bottom nav floats translucently over content
/// and tab taps reach the screens); a persistent `TopBar` rides the top safe area, and a
/// separated "+" record button sits on the trailing side of the bottom nav.
struct HomeRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BatteryReading.timestamp, order: .reverse) private var readings: [BatteryReading]

    @State private var manager: RingManager?
    @State private var sync = SyncCoordinator()
    @State private var profile = ProfileStore()
    @State private var recorder = WorkoutRecorder()
    @State private var date = Calendar.current.startOfDay(for: .now)
    @State private var tab = HomeTab.summary
    @State private var sheet: HomeSheet?
    @State private var justUpdated = false
    @State private var scrollSignal = 0

    enum HomeTab: Hashable { case summary, sleep, recovery, strain, record }
    enum HomeSheet: Int, Identifiable { case profile, sync, record, activeWorkout; var id: Int { rawValue } }

    /// Selecting the separated "+" opens the record drawer; any real tab change scrolls the new
    /// screen to its top.
    private var tabSelection: Binding<HomeTab> {
        Binding(
            get: { tab },
            set: { selected in
                if selected == .record {
                    sheet = .record
                } else {
                    tab = selected
                    scrollSignal += 1
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            topChrome
            tabs
        }
            .environment(\.scrollToTopSignal, scrollSignal)
            .sensoryFeedback(.success, trigger: recorder.isRecording)
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
                case .profile: ProfileView(profile: profile)
                case .sync: MacSyncView(sync: sync, onSyncNow: pushSync)
                case .record: RecordWorkoutForm(recorder: recorder)
                case .activeWorkout:
                    ActiveWorkoutDrawer(recorder: recorder)
                        .presentationDetents([.medium])
                }
            }
    }

    /// Translucent top chrome (avatar · date · battery · sync) that reserves its own space and
    /// extends the bar material up into the status-bar area — no flat-black nav strip.
    private var topChrome: some View {
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
        }
        .background(.bar, ignoresSafeAreaEdges: .top)
    }

    /// The active-workout bottom accessory is attached only while recording (no empty bar).
    @ViewBuilder private var tabs: some View {
        if recorder.isRecording {
            tabView.tabViewBottomAccessory {
                ActiveWorkoutAccessory(recorder: recorder) { sheet = .activeWorkout }
            }
        } else {
            tabView
        }
    }

    private var tabView: some View {
        TabView(selection: tabSelection) {
            Tab("Summary", systemImage: "circle.grid.2x2", value: HomeTab.summary) { screen(for: .summary) }
            Tab("Sleep", systemImage: "moon", value: HomeTab.sleep) { screen(for: .sleep) }
            Tab("Recovery", systemImage: "heart", value: HomeTab.recovery) { screen(for: .recovery) }
            Tab("Strain", systemImage: "bolt", value: HomeTab.strain) { screen(for: .strain) }
            Tab("Record", systemImage: "plus", value: HomeTab.record, role: .search) {
                screen(for: tab) // mirrors the active screen; the tap is intercepted
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.primary) // bottom nav uses a neutral selection color, not the brand hue
    }

    @ViewBuilder private func screen(for tab: HomeTab) -> some View {
        switch tab {
        case .summary:
            DayPager(date: $date) { day in
                OverviewView(metrics: .sample, date: day, recorder: recorder, openDomain: openDomain)
            }
        case .sleep: DayPager(date: $date) { _ in SleepView() }
        case .recovery: DayPager(date: $date) { _ in RecoveryView() }
        case .strain: DayPager(date: $date) { _ in StrainView() }
        case .record: Color.clear
        }
    }

    private func openDomain(_ domain: Domain) {
        switch domain {
        case .sleep: tab = .sleep
        case .recovery: tab = .recovery
        case .strain: tab = .strain
        }
        scrollSignal += 1
    }

    private func pushSync() {
        let dtos = readings.prefix(50).map {
            BatteryDTO(timestamp: $0.timestamp, level: $0.level, isCharging: $0.isCharging)
        }
        sync.push(Array(dtos))
    }
}
