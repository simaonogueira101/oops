import SwiftUI

// Display styles with no standard Dynamic Type text style (large hero numbers and glyphs).
// Backed by @ScaledMetric so they track the user's type size — this file is the single
// source of truth, so the font-size lint rules are intentionally disabled here only.
// swiftlint:disable no_hardcoded_font_size no_font_system_size_init

/// Large hero metric value (e.g. a score or elapsed time) that scales with Dynamic Type.
private struct MetricValueStyle: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
    }
}

/// Oversized status glyph (e.g. the battery icon) that scales with Dynamic Type.
private struct HeroGlyphStyle: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 84
    func body(content: Content) -> some View {
        content.font(.system(size: size))
    }
}

extension View {
    func metricValueStyle() -> some View { modifier(MetricValueStyle()) }
    func heroGlyphStyle() -> some View { modifier(HeroGlyphStyle()) }
}

extension Font {
    /// Prominent in-card value (e.g. the big number on a summary card).
    static let cardValue = Font.title.weight(.semibold)
    /// Secondary in-card value (stat tiles, list values).
    static let cardValueSecondary = Font.title3.weight(.semibold)
    /// Large header glyph (onboarding) — the system large-title style.
    static let headerGlyph = Font.largeTitle
    /// Medium header glyph (redeploy monitor) — the system title style.
    static let sectionGlyph = Font.title
}
// swiftlint:enable no_hardcoded_font_size no_font_system_size_init
