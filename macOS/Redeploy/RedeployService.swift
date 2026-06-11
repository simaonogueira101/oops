import Foundation
import Observation
import AppKit

struct RedeployStatus: Codable, Equatable {
    let date: Date
    let success: Bool
    let message: String
}

/// Manages the headless auto-redeploy: a LaunchAgent that periodically re-signs and
/// reinstalls Oops onto the iPhone (free certs expire every 7 days), plus a manual
/// "Redeploy now". The Mac app owns this so it's a single install with no extra setup.
@MainActor
@Observable
final class RedeployService {
    let projectDir = NSString(string: "~/Developer/oops").expandingTildeInPath
    let label = "com.simao.oops.redeploy"
    let intervalDays = 3

    private let supportDir = (NSHomeDirectory() as NSString)
        .appendingPathComponent("Library/Application Support/Oops")
    private var scriptPath: String { (supportDir as NSString).appendingPathComponent("redeploy.sh") }
    private var statusPath: String { (supportDir as NSString).appendingPathComponent("status.json") }
    private var lastSuccessPath: String { (supportDir as NSString).appendingPathComponent("last_success.txt") }
    private var plistPath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    var status: RedeployStatus?
    var lastSuccess: Date?
    var isEnabled = false
    var isRedeploying = false

    /// Days until the current free signing expires (last successful redeploy + 7 days).
    var daysUntilExpiry: Int? {
        guard let lastSuccess else { return nil }
        let expiry = lastSuccess.addingTimeInterval(7 * 24 * 3600)
        return Calendar.current.dateComponents([.day], from: Date(), to: expiry).day
    }

    // MARK: Status

    func refresh() async {
        let enabled = await Shell.run("launchctl print gui/$(id -u)/\(label)")
        isEnabled = enabled.succeeded

        if let data = FileManager.default.contents(atPath: statusPath) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            status = try? decoder.decode(RedeployStatus.self, from: data)
        }
        if let text = try? String(contentsOfFile: lastSuccessPath, encoding: .utf8) {
            let iso = ISO8601DateFormatter()
            lastSuccess = iso.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: Enable / disable

    func enable() async {
        writeFiles()
        _ = await Shell.run("launchctl bootout gui/$(id -u)/\(label) 2>/dev/null; "
                            + "launchctl bootstrap gui/$(id -u) '\(plistPath)'")
        await refresh()
    }

    func disable() async {
        _ = await Shell.run("launchctl bootout gui/$(id -u)/\(label)")
        try? FileManager.default.removeItem(atPath: plistPath)
        await refresh()
    }

    // MARK: Manual redeploy

    func redeployNow() async {
        guard !isRedeploying else { return }
        isRedeploying = true
        defer { isRedeploying = false }
        writeFiles()
        _ = await Shell.run("OOPS_SKIP_MAC=1 /bin/zsh '\(scriptPath)'")
        await refresh()
    }

    // MARK: File generation

    private func writeFiles() {
        try? FileManager.default.createDirectory(atPath: supportDir, withIntermediateDirectories: true)
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try? plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
    }

    private var script: String {
        """
        #!/bin/zsh
        export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        SUPPORT="\(supportDir)"
        STATUS="$SUPPORT/status.json"
        LOG="$SUPPORT/redeploy.log"
        LOCK="$SUPPORT/redeploy.lock"
        exec >> "$LOG" 2>&1
        write_status() { printf '{"date":"%s","success":%s,"message":"%s"}\\n' "$(date -u +%FT%TZ)" "$1" "$2" > "$STATUS"; }

        # Single-instance lock (atomic mkdir) so a scheduled run and a manual one can't collide.
        if ! mkdir "$LOCK" 2>/dev/null; then
          echo "=== $(date) skipped: another redeploy is already running ==="
          exit 0
        fi
        trap 'rmdir "$LOCK" 2>/dev/null' EXIT

        echo "=== $(date) redeploy ==="
        cd "\(projectDir)" || { write_status false "project missing"; exit 1; }

        UDID=$(xcrun xctrace list devices 2>/dev/null | grep -i iphone | grep -v Simulator | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}' | head -1)
        CORE=$(xcrun devicectl list devices 2>/dev/null | grep -i iphone | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -1)
        TEAM=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamManagerLastSelectedTeamID 2>/dev/null)

        [ -z "$UDID" ] || [ -z "$CORE" ] && { write_status false "iPhone not reachable"; exit 0; }
        [ -z "$TEAM" ] && { write_status false "No Xcode team"; exit 0; }
        BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)

        command -v xcodegen >/dev/null && xcodegen generate >/dev/null 2>&1

        xcodebuild -project Oops.xcodeproj -scheme Oops -destination "platform=iOS,id=$UDID" \\
          -configuration Debug -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" \\
          CURRENT_PROJECT_VERSION="$BUILD" \\
          -derivedDataPath build_device build > /tmp/oops_redeploy_build.log 2>&1

        if ! grep -q "BUILD SUCCEEDED" /tmp/oops_redeploy_build.log; then write_status false "Build failed"; exit 0; fi

        install_app() { xcrun devicectl device install app --device "$CORE" build_device/Build/Products/Debug-iphoneos/Oops.app; }

        if install_app; then
          write_status true "Redeployed"; date -u +%FT%TZ > "$SUPPORT/last_success.txt"
        else
          echo "install failed (likely device busy); retrying in 5s…"; sleep 5
          if install_app; then
            write_status true "Redeployed (after retry)"; date -u +%FT%TZ > "$SUPPORT/last_success.txt"
          else
            write_status false "Install failed (after retry)"
          fi
        fi

        # --- Mac companion: rebuild + relaunch itself (skipped when run from the app,
        # so a manual "Redeploy now" doesn't kill the app it's running in). ---
        if [ -z "$OOPS_SKIP_MAC" ]; then
          xcodebuild -project Oops.xcodeproj -scheme OopsMac -configuration Debug \\
            -derivedDataPath build_mac CURRENT_PROJECT_VERSION="$BUILD" \\
            CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build > /tmp/oops_mac_build.log 2>&1
          if grep -q "BUILD SUCCEEDED" /tmp/oops_mac_build.log; then
            pkill -9 -f "Contents/MacOS/OopsMac" 2>/dev/null
            sleep 1
            rm -rf "/Applications/Oops.app"
            cp -R build_mac/Build/Products/Debug/OopsMac.app "/Applications/Oops.app"
            open "/Applications/Oops.app"
          fi
        fi
        echo "=== done ==="
        """
    }

    // MARK: Log

    func logTail(_ lines: Int = 60) -> String {
        let path = (supportDir as NSString).appendingPathComponent("redeploy.log")
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return "No log yet." }
        let all = content.split(separator: "\n", omittingEmptySubsequences: false)
        return all.suffix(lines).joined(separator: "\n")
    }

    func revealLog() {
        let path = (supportDir as NSString).appendingPathComponent("redeploy.log")
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: supportDir))
        }
    }

    private var plist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key><string>\(label)</string>
          <key>ProgramArguments</key>
          <array><string>/bin/zsh</string><string>\(scriptPath)</string></array>
          <key>StartInterval</key><integer>\(intervalDays * 24 * 3600)</integer>
          <key>RunAtLoad</key><true/>
          <key>WatchPaths</key>
          <array><string>\(projectDir)/.git/refs/heads/main</string></array>
          <key>StandardOutPath</key><string>\(supportDir)/launchd.log</string>
          <key>StandardErrorPath</key><string>\(supportDir)/launchd.log</string>
        </dict>
        </plist>
        """
    }
}
