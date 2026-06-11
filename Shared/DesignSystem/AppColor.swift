import SwiftUI

/// Semantic color tokens. Prefer these — or SwiftUI's built-in semantic colors
/// (.primary / .secondary / .tint) — over hardcoded RGB, which breaks dark mode and
/// increased-contrast. Enforced by SwiftLint. Cross-platform (no UIKit/AppKit).
enum AppColor {
    static let label = Color.primary
    static let secondaryLabel = Color.secondary
    static let accent = Color.accentColor
    static let positive = Color.green
    static let warning = Color.orange
    static let negative = Color.red
    // Brand colors live in the asset catalog, e.g. Color("BrandPrimary").
}
