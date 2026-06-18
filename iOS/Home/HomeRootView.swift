import SwiftUI
import SwiftData

/// iPhone root: the `TabView` is the root (so the bottom nav floats translucently over content
/// and tab taps reach the screens); a persistent `TopBar` rides the top safe area, and a
/// separated "+" record button sits on the trailing side of the bottom nav.
struct HomeRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \BatteryReading.timestamp, order: .reverse) private var readings: [BatteryReading]

    @State private var manager: RingManager?
    @State private var health: (any HealthData)?
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
        tabs
            .environment(\.healthData, health ?? MockHealthData())
            .overlay(alignment: .top) { topChrome }
            .scrollEdgeEffectStyle(.soft, for: .all)
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

                if health == nil {
                    health = RingHealthData(modelContext: modelContext)
                }
                if manager == nil {
                    let manager = RingManager(transport: RingTransportFactory.make(), modelContext: modelContext)
                    // Show the last recorded percentage immediately instead of a blank pill,
                    // until the first live read lands.
                    if let last = readings.first {
                        manager.batteryStatus = BatteryStatus(level: last.level, isCharging: last.isCharging)
                    }
                    self.manager = manager
                }
                await manager?.sync()
            }
            .task {
                // Periodic top-up while the app stays open. Ring battery moves slowly, so a
                // gentle cadence is plenty and spares both batteries and the flaky BLE stack.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30 * 60))
                    if Task.isCancelled { break }
                    await manager?.sync()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                // Refresh when the app returns to the foreground.
                if phase == .active { Task { await manager?.sync() } }
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

    /// The glass top bar floats over the content — fully transparent nav, no scrim.
    private var topChrome: some View {
        VStack(spacing: 0) {
            TopBar(
                profile: profile,
                date: $date,
                battery: manager?.batteryStatus,
                isUpdatingBattery: manager?.isBusy ?? false,
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
        let provider = health ?? MockHealthData()
        switch tab {
        case .summary:
            DayPager(date: $date) { day in
                OverviewView(metrics: provider.dayMetrics(for: day),
                             date: day, recorder: recorder, openDomain: openDomain)
            }
        case .sleep: DayPager(date: $date) { day in SleepView(date: day) }
        case .recovery: DayPager(date: $date) { day in RecoveryView(date: day) }
        case .strain: DayPager(date: $date) { day in StrainView(date: day) }
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
