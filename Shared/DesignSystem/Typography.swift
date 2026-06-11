import SwiftUI

// Display sizes that have no standard Dynamic Type text style (large hero numbers and
// glyphs). This file is the single source of truth for them, so the font-size lint rules
// are intentionally disabled here only — everywhere else must use these tokens or a
// built-in text style (.body, .headline, …).
// swiftlint:disable no_hardcoded_font_size no_font_system_size_init
extension Font {
    /// Large hero metric value, e.g. the battery percentage.
    static let metricValue = Font.system(size: 56, weight: .semibold, design: .rounded)
    /// Oversized status glyph (e.g. the battery icon).
    static let heroGlyph = Font.system(size: 84)
    /// Large header glyph (onboarding).
    static let headerGlyph = Font.system(size: 34)
    /// Medium header glyph (redeploy monitor).
    static let sectionGlyph = Font.system(size: 28)
}
// swiftlint:enable no_hardcoded_font_size no_font_system_size_init
