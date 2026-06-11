import Foundation
import Observation

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
        _ = await Shell.run("/bin/zsh '\(scriptPath)'")
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
        exec >> "$LOG" 2>&1
        echo "=== $(date) redeploy ==="
        write_status() { printf '{"date":"%s","success":%s,"message":"%s"}\\n' "$(date -u +%FT%TZ)" "$1" "$2" > "$STATUS"; }

        cd "\(projectDir)" || { write_status false "project missing"; exit 1; }

        UDID=$(xcrun xctrace list devices 2>/dev/null | grep -i iphone | grep -v Simulator | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}' | head -1)
        CORE=$(xcrun devicectl list devices 2>/dev/null | grep -i iphone | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -1)
        TEAM=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamManagerLastSelectedTeamID 2>/dev/null)

        [ -z "$UDID" ] || [ -z "$CORE" ] && { write_status false "iPhone not reachable"; exit 0; }
        [ -z "$TEAM" ] && { write_status false "No Xcode team"; exit 0; }

        command -v xcodegen >/dev/null && xcodegen generate >/dev/null 2>&1

        xcodebuild -project Oops.xcodeproj -scheme Oops -destination "platform=iOS,id=$UDID" \\
          -configuration Debug -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" \\
          -derivedDataPath build_device build > /tmp/oops_redeploy_build.log 2>&1

        if ! grep -q "BUILD SUCCEEDED" /tmp/oops_redeploy_build.log; then write_status false "Build failed"; exit 0; fi

        if xcrun devicectl device install app --device "$CORE" build_device/Build/Products/Debug-iphoneos/Oops.app; then
          write_status true "Redeployed"
          date -u +%FT%TZ > "$SUPPORT/last_success.txt"
        else
          write_status false "Install failed"
        fi
        echo "=== done ==="
        """
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
          <key>StandardOutPath</key><string>\(supportDir)/launchd.log</string>
          <key>StandardErrorPath</key><string>\(supportDir)/launchd.log</string>
        </dict>
        </plist>
        """
    }
}
