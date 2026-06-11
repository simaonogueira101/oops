import SwiftUI
import Observation

/// Local profile (photo + name). No public iOS API exposes the "me" contact card or the
/// Apple Account photo to third-party apps, so the user sets their own via PhotosPicker;
/// we fall back to initials, like Apple Health.
@MainActor
@Observable
final class ProfileStore {
    private(set) var name: String
    private(set) var imageData: Data?

    init() {
        name = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        imageData = try? Data(contentsOf: Self.imageURL)
    }

    func setName(_ newName: String) {
        name = newName
        UserDefaults.standard.set(newName, forKey: Self.nameKey)
    }

    func setImage(_ data: Data?) {
        imageData = data
        if let data {
            try? data.write(to: Self.imageURL)
        } else {
            try? FileManager.default.removeItem(at: Self.imageURL)
        }
    }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "" : String(letters).uppercased()
    }

    private static let nameKey = "profile.name"
    private static var imageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile.jpg")
    }
}

/// Placeholder daily metrics until the ring provides real recovery/strain/sleep data.
struct DayMetrics: Equatable {
    var recovery: Double          // 0...1
    var strain: Double            // 0...21 (Whoop-like scale)
    var hrv: Int                  // ms
    var sleepPerformance: Double  // 0...1

    /// Strain mapped to 0...1 for the ring.
    var strainFraction: Double { min(max(strain / 21, 0), 1) }

    static let sample = DayMetrics(recovery: 0.58, strain: 4.9, hrv: 40, sleepPerformance: 0.73)
}
