import Foundation
import Observation

/// Launches Oops at login via a lightweight LaunchAgent. (More reliable than SMAppService
/// for a locally-built, ad-hoc-signed app, and consistent with how we manage the redeploy
/// agent.)
@MainActor
@Observable
final class LoginItem {
    var isEnabled = false

    private let label = "com.simao.oops.mac.login"
    private var appPath: String { "/Applications/Oops.app" }
    private var plistPath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    func refresh() async {
        isEnabled = await Shell.run("launchctl print gui/$(id -u)/\(label)").succeeded
    }

    func enable() async {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key><string>\(label)</string>
          <key>ProgramArguments</key>
          <array><string>/usr/bin/open</string><string>\(appPath)</string></array>
          <key>RunAtLoad</key><true/>
        </dict>
        </plist>
        """
        try? plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
        _ = await Shell.run(
            "launchctl bootout gui/$(id -u)/\(label) 2>/dev/null; "
            + "launchctl bootstrap gui/$(id -u) '\(plistPath)'")
        await refresh()
    }

    func disable() async {
        _ = await Shell.run("launchctl bootout gui/$(id -u)/\(label)")
        try? FileManager.default.removeItem(atPath: plistPath)
        await refresh()
    }
}
