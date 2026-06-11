import SwiftUI

/// Value-based navigation routes pushed onto a tab's `NavigationStack`.
enum AppRoute: Hashable {
    case sleep, recovery, strain
    case heartRate, hrv, spo2, stress, bodyTemp, respiratory
    case workouts, hrZones, trends, journal, settings, deviceStatus
}

/// Resolves a route to its destination screen. Shared by iOS and macOS.
@MainActor
struct RouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .sleep: SleepView()
        case .recovery: RecoveryView()
        case .strain: StrainView()
        case .heartRate: MetricDetailScreen.heartRate()
        case .hrv: MetricDetailScreen.hrv()
        case .spo2: MetricDetailScreen.spo2()
        case .stress: MetricDetailScreen.stress()
        case .bodyTemp: MetricDetailScreen.bodyTemp()
        case .respiratory: MetricDetailScreen.respiratory()
        case .workouts: WorkoutsView()
        case .hrZones: HRZonesView()
        case .trends: TrendsScreen()
        case .journal: JournalView()
        case .settings: SettingsView()
        case .deviceStatus: DeviceStatusView()
        }
    }
}

extension View {
    /// Registers the app's route destinations on an enclosing `NavigationStack`.
    func appNavigationDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
    }

    /// Wrap any view (e.g. a `Card`) so tapping it pushes the given route.
    func navigates(to route: AppRoute) -> some View {
        NavigationLink(value: route) { self }.buttonStyle(.plain)
    }

    /// Cross-platform inline navigation title (macOS has no title display mode).
    @ViewBuilder
    func inlineNavigationTitle(_ title: String) -> some View {
        #if os(iOS)
        navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        #else
        navigationTitle(title)
        #endif
    }
}
