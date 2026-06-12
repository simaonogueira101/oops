import SwiftUI
import SwiftData

/// iPhone root: four domain tabs, each in its own `NavigationStack` with a large title and a
/// shared toolbar (battery · sync · record · profile). The active workout surfaces as a
/// Now-Playing-style bottom accessory above the tab bar.
struct HomeRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BatteryReading.timestamp, order: .reverse) private var readings: [BatteryReading]

    @State private var manager: RingManager?
    @State private var sync = SyncCoordinator()
    @State private var profile = ProfileStore()
    @State private var recorder = WorkoutRecorder()
    @State private var date = Date()
    @State private var tab = HomeTab.summary
    @State private var sheet: HomeSheet?
    @State private var justUpdated = false

    enum HomeTab: Hashable { case summary, sleep, recovery, strain }
    enum HomeSheet: Int, Identifiable { case profile, sync, record, battery; var id: Int { rawValue } }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Summary", systemImage: "circle.grid.2x2", value: HomeTab.summary) {
                NavigationStack {
                    OverviewView(metrics: .sample, date: $date, recorder: recorder,
                                 openDomain: openDomain)
                        .navigationSubtitle(subtitleText)
                        .toolbar { sharedToolbar }
                }
            }
            Tab("Sleep", systemImage: "moon", value: HomeTab.sleep) {
                NavigationStack {
                    SleepView().toolbar { sharedToolbar }
                }
            }
            Tab("Recovery", systemImage: "heart", value: HomeTab.recovery) {
                NavigationStack {
                    RecoveryView().toolbar { sharedToolbar }
                }
            }
            Tab("Strain", systemImage: "bolt", value: HomeTab.strain) {
                NavigationStack {
                    StrainView().toolbar { sharedToolbar }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if recorder.isRecording {
                ActiveWorkoutAccessory(recorder: recorder)
            }
        }
        .overlay(alignment: .top) {
            if justUpdated {
                UpdatedBanner(build: BuildInfo.build) {
                    withAnimation { justUpdated = false }
                }
            }
        }
        .sensoryFeedback(.success, trigger: recorder.isRecording)
        .background(AppColor.background.ignoresSafeArea())
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
            case .battery:
                if let manager {
                    BatteryScreen(manager: manager)
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var sharedToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                sheet = .battery
            } label: {
                HStack(spacing: Spacing.xxs) {
                    if let battery = manager?.batteryStatus {
                        Text("\(battery.level)%").font(.caption.weight(.medium)).monospacedDigit()
                    }
                    Image(systemName: batterySymbol)
                        .foregroundStyle(manager?.batteryStatus?.isCharging == true ? AppColor.positive : .primary)
                }
            }
            .accessibilityLabel(batteryAccessibilityLabel)

            Button("Mac sync", systemImage: "laptopcomputer") { sheet = .sync }
                .foregroundStyle(sync.state == .sent ? AppColor.positive : .primary)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Record workout", systemImage: "plus") { sheet = .record }
            Button { sheet = .profile } label: { Avatar(profile: profile, size: 30) }
                .accessibilityLabel("Profile")
        }
    }

    private var subtitleText: String {
        Calendar.current.isDateInToday(date)
            ? "Today"
            : date.formatted(.dateTime.weekday(.wide).month().day())
    }

    private var batterySymbol: String {
        guard let status = manager?.batteryStatus else { return "battery.50percent" }
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
        guard let status = manager?.batteryStatus else { return "Ring battery" }
        return "Ring battery \(status.level) percent\(status.isCharging ? ", charging" : "")"
    }

    private func openDomain(_ domain: Domain) {
        switch domain {
        case .sleep: tab = .sleep
        case .recovery: tab = .recovery
        case .strain: tab = .strain
        }
    }

    private func pushSync() {
        let dtos = readings.prefix(50).map {
            BatteryDTO(timestamp: $0.timestamp, level: $0.level, isCharging: $0.isCharging)
        }
        sync.push(Array(dtos))
    }
}
