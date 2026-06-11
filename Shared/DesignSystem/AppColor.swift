import SwiftUI

/// Semantic color tokens — the app's entire palette. Backed by asset colors with light + dark
/// appearances (see `Shared/Assets.xcassets/Colors`). SwiftUI's built-in color presets are banned
/// by SwiftLint so the palette stays small; use these tokens or .primary/.secondary/.tint.
/// Cross-platform (no UIKit/AppKit).
enum AppColor {
    // Text & system
    static let label = Color.primary
    static let secondaryLabel = Color.secondary

    // Domains
    static let recovery = Color("Recovery")
    static let sleep = Color("Sleep")
    static let strain = Color("Strain")
    /// App tint/accent (same hue as the recovery domain).
    static let accent = Color("Recovery")

    // Status — reused app-wide for score bands, deltas, charging, and errors (keeps count low).
    static let positive = Color("Positive")
    static let caution = Color("Caution")
    static let negative = Color("Negative")
    /// Back-compat alias for the old `warning` token.
    static let warning = Color("Caution")

    // Neutrals
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let surfaceElevated = Color("SurfaceElevated")
    static let separator = Color("Separator")
    static let track = Color("Track")
}
