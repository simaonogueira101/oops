import SwiftUI

/// Value-based navigation routes pushed onto a tab's `NavigationStack`.
enum AppRoute: Hashable {
    case sleep, recovery, strain
    case heartRate, hrv, bodyTemp, respiratory
    case workouts, hrZones
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
        case .bodyTemp: MetricDetailScreen.bodyTemp()
        case .respiratory: MetricDetailScreen.respiratory()
        case .workouts: WorkoutsView()
        case .hrZones: HRZonesView()
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
        NavigationLink(value: route) { self }.buttonStyle(CardLinkStyle())
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

/// Native-feeling pressed state for tappable cards (subtle scale + dim, like a touched list row).
struct CardLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
