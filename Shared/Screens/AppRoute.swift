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
    /// Wrap any view (e.g. a `Card`) so tapping it opens the route in a bottom drawer.
    func navigates(to route: AppRoute) -> some View {
        DrawerLink(route: route) { self }
    }

}

/// A tappable label that presents its route in a bottom drawer (cards open drawers, not pushes).
/// The drawer gets its own `NavigationStack` so inner links (e.g. workout rows) push within it.
struct DrawerLink<Label: View>: View {
    let route: AppRoute
    @ViewBuilder var label: () -> Label
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: { label() }
            .buttonStyle(CardLinkStyle())
            .cardDrawer(isPresented: $presented) {
                NavigationStack { RouteDestination(route: route) }
            }
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
