import SwiftUI

private struct ScrollToTopKey: EnvironmentKey { static let defaultValue = 0 }

extension EnvironmentValues {
    /// Bumped when a bottom-tab is selected; tab screens scroll back to the top in response.
    var scrollToTopSignal: Int {
        get { self[ScrollToTopKey.self] }
        set { self[ScrollToTopKey.self] = newValue }
    }
}

/// A `ScrollView` that (1) clears the floating top-bar pills so content starts below them at
/// rest but scrolls *under* them (transparent nav + glass refraction), and (2) returns to the
/// top whenever the bottom-nav signal changes (tapping a tab shows its view from the top).
struct TopScrollView<Content: View>: View {
    @Environment(\.scrollToTopSignal) private var signal
    @ViewBuilder var content: () -> Content
    private let topID = "screen-top"

    /// Clearance so content starts below the floating top-bar pills at rest (iOS only).
    #if os(iOS)
    private let topClearance: CGFloat = 52
    #else
    private let topClearance: CGFloat = 0
    #endif

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: topClearance).id(topID)
                content()
            }
            .onChange(of: signal) { _, _ in
                withAnimation(.snappy) { proxy.scrollTo(topID, anchor: .top) }
            }
        }
    }
}
