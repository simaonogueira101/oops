import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Semantic color tokens — the app's entire palette. The six hues (3 domains + 3 statuses)
/// are asset-backed with light + dark appearances; the neutrals are the **system's dynamic
/// grouped-background colors** so cards get Apple's elevation, Increase Contrast, and
/// dark-mode behavior for free. SwiftUI's built-in color presets are banned by SwiftLint;
/// use these tokens or .primary/.secondary/.tint.
enum AppColor {
    // Text & system
    static let label = Color.primary
    static let secondaryLabel = Color.secondary

    // Domains
    static let recovery = Color("Recovery")
    static let sleep = Color("Sleep")
    static let strain = Color("Strain")
    /// App tint — the AccentColor asset (Recovery hue), so controls default to it everywhere.
    static let accent = Color.accentColor

    // Status — reused app-wide for score bands, deltas, charging, and errors (keeps count low).
    static let positive = Color("Positive")
    static let caution = Color("Caution")
    static let negative = Color("Negative")
    /// Back-compat alias for the old `warning` token.
    static let warning = Color("Caution")

    // Neutrals — dynamic system colors (grouped style, like Apple Health).
    #if canImport(UIKit)
    static let background = Color(UIColor.systemGroupedBackground)
    static let surface = Color(UIColor.secondarySystemGroupedBackground)
    static let surfaceElevated = Color(UIColor.tertiarySystemGroupedBackground)
    static let separator = Color(UIColor.separator)
    static let track = Color(UIColor.systemFill)
    #else
    static let background = Color(NSColor.windowBackgroundColor)
    static let surface = Color(NSColor.controlBackgroundColor)
    static let surfaceElevated = Color(NSColor.underPageBackgroundColor)
    static let separator = Color(NSColor.separatorColor)
    static let track = Color(NSColor.quaternaryLabelColor)
    #endif
}
