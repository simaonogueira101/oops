import SwiftUI

/// Qualitative band for a 0–100 score. Drives the status color/label used across the app.
enum ScoreBand: CaseIterable {
    case poor, fair, good, optimal

    init(score: Int) {
        switch max(0, min(100, score)) {
        case ..<35: self = .poor
        case ..<60: self = .fair
        case ..<80: self = .good
        default: self = .optimal
        }
    }

    var label: String {
        switch self {
        case .poor: return "Pay attention"
        case .fair: return "Fair"
        case .good: return "Good"
        case .optimal: return "Optimal"
        }
    }

    /// Status color — reuses the semantic trio only (keeps the palette small).
    var color: Color {
        switch self {
        case .poor: return AppColor.negative
        case .fair: return AppColor.caution
        case .good, .optimal: return AppColor.positive
        }
    }
}
