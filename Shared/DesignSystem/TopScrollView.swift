import SwiftUI

private struct ScrollToTopKey: EnvironmentKey { static let defaultValue = 0 }

extension EnvironmentValues {
    /// Bumped when a bottom-tab is selected; tab screens scroll back to the top in response.
    var scrollToTopSignal: Int {
        get { self[ScrollToTopKey.self] }
        set { self[ScrollToTopKey.self] = newValue }
    }
}

/// A `ScrollView` that returns to the top whenever the bottom-nav signal changes (so tapping a
/// tab shows its view from the top, like a native tab bar).
struct TopScrollView<Content: View>: View {
    @Environment(\.scrollToTopSignal) private var signal
    @ViewBuilder var content: () -> Content
    private let topID = "screen-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: 0).id(topID)
                content()
            }
            .onChange(of: signal) { _, _ in
                withAnimation(.snappy) { proxy.scrollTo(topID, anchor: .top) }
            }
        }
    }
}
