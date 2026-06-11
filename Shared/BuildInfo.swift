import Foundation

/// App version + build, read from the bundle. The build number is the git commit count,
/// stamped in by the redeploy (CURRENT_PROJECT_VERSION), so each build is distinct.
enum BuildInfo {
    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var build: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
    }

    static var label: String { "v\(shortVersion) · build \(build)" }
}
