import SwiftUI

/// Value-based routes presented from cards. Domain tabs (Sleep/Recovery/Strain) are NOT routes —
/// cards for those switch tabs via `openDomain`; drawers are reserved for drill-in content.
enum AppRoute: Hashable {
    case heartRate, hrv, bodyTemp, respiratory
    case workouts, hrZones
}

/// A health domain that owns a tab. Summary cards switch to the tab instead of presenting a
/// duplicate of it in a sheet.
enum Domain {
    case sleep, recovery, strain
}

/// Resolves a route to its destination screen. Shared by iOS and macOS.
@MainActor
struct RouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .heartRate: MetricDetailScreen.heartRate()
        case .hrv: MetricDetailScreen.hrv()
        case .bodyTemp: MetricDetailScreen.bodyTemp()
        case .respiratory: MetricDetailScreen.respiratory()
        case .workouts: WorkoutsView()
        case .hrZones: HRZonesView()
        }
    }
}

private struct InsideDrawerKey: EnvironmentKey {
    static let defaultValue = false
}

private struct DisplayDateKey: EnvironmentKey {
    static let defaultValue = Date.now
}

extension EnvironmentValues {
    /// The day currently selected on Summary — every screen's `PageHeader` shows it.
    var displayDate: Date {
        get { self[DisplayDateKey.self] }
        set { self[DisplayDateKey.self] = newValue }
    }
}

extension EnvironmentValues {
    /// True inside a presented drawer — nested `navigates(to:)` push within the drawer's own
    /// `NavigationStack` (with a back button) instead of stacking another sheet.
    var isInsideDrawer: Bool {
        get { self[InsideDrawerKey.self] }
        set { self[InsideDrawerKey.self] = newValue }
    }
}

extension View {
    /// Wrap any view (e.g. a `Card`) so tapping it opens the route — a bottom drawer at the
    /// top level, a push when already inside a drawer.
    func navigates(to route: AppRoute) -> some View {
        DrawerLink(route: route) { self }
    }

    /// Cross-platform inline title for drawer/detail content.
    func drawerTitle(_ title: String) -> some View {
        navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
    }
}

/// A tappable label that presents its route in a system bottom drawer with a title and a close
/// button; inside a drawer it becomes a `NavigationLink` push instead (no sheet-on-sheet).
struct DrawerLink<Label: View>: View {
    let route: AppRoute
    @ViewBuilder var label: () -> Label
    @State private var presented = false
    @Environment(\.isInsideDrawer) private var isInsideDrawer

    var body: some View {
        if isInsideDrawer {
            NavigationLink(value: route) { label() }
                .buttonStyle(CardLinkStyle())
        } else {
            Button { presented = true } label: { label() }
                .buttonStyle(CardLinkStyle())
                .cardDrawer(isPresented: $presented) {
                    NavigationStack {
                        DrawerRoot { RouteDestination(route: route) }
                            .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
                    }
                    .environment(\.isInsideDrawer, true)
                }
        }
    }
}

/// Gives every drawer the standard system close affordance.
struct DrawerRoot<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    private var closePlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .cancellationAction
        #endif
    }

    var body: some View {
        content()
            .toolbar {
                ToolbarItem(placement: closePlacement) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
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
