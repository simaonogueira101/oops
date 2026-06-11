import Foundation
import Observation

// MARK: - Types

enum StepState: Equatable {
    case pending          // waiting on a previous step
    case checking
    case needsAction      // user must do something, then re-check
    case running          // performing an automated action
    case done
    case failed(String)
}

struct SetupStep: Identifiable {
    enum Kind: String, CaseIterable { case xcode, account, device, developerMode, install, trust }
    let kind: Kind
    let title: String
    let summary: String
    var state: StepState = .pending
    var detail: String = ""
    var instructions: [String] = []
    var actionTitle: String? = nil   // nil = no button beyond "Re-check"
    var id: String { kind.rawValue }
}

struct DeviceInfo: Equatable {
    var name: String
    var model: String
    var iosVersion: String
    var buildUDID: String      // for xcodebuild -destination
    var coreDeviceID: String   // for xcrun devicectl
}

// MARK: - Parsing (pure, deterministic)

enum SetupParse {
    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }

    /// xcodebuild -showdestinations: true if the physical device is listed without the
    /// "Developer Mode disabled" error.
    static func developerModeEnabled(in showDestinations: String) -> Bool {
        let deviceLines = showDestinations
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.contains("platform:iOS") && !$0.contains("Simulator") && !$0.contains("placeholder") }
        guard !deviceLines.isEmpty else { return false }
        return !deviceLines.contains { $0.contains("Developer Mode disabled") }
    }
}

// MARK: - Model

@MainActor
@Observable
final class SetupModel {
    // Project location. (For distribution this would be bundled/configurable; for now it's
    // the working copy.)
    let projectDir = NSString(string: "~/Developer/oops").expandingTildeInPath
    let scheme = "Oops"
    let bundleID = "com.simao.oops"

    var steps: [SetupStep]
    var device: DeviceInfo?
    var teamID: String?
    var teamName: String?
    var log: String = ""
    var isRunning = false

    init() {
        steps = SetupStep.Kind.allCases.map { SetupModel.template(for: $0) }
    }

    var isComplete: Bool { steps.allSatisfy { $0.state == .done } }
    var completedCount: Int { steps.filter { $0.state == .done }.count }

    // MARK: Step templates

    private static func template(for kind: SetupStep.Kind) -> SetupStep {
        switch kind {
        case .xcode:
            return SetupStep(kind: kind, title: "Xcode",
                summary: "Apple's developer tools, used to sign and install Oops on your iPhone.",
                instructions: ["Install Xcode from the App Store (it's a large download), then re-check."],
                actionTitle: "Open App Store")
        case .account:
            return SetupStep(kind: kind, title: "Apple ID in Xcode",
                summary: "Xcode signs Oops with your free Apple ID. This is the one step only you can do.",
                instructions: [
                    "In Xcode: menu → Settings… (⌘,)",
                    "Open the Accounts tab",
                    "Click + → Apple ID → sign in (password + 2-factor)",
                    "Your name + “Personal Team” should appear, then re-check."],
                actionTitle: "Open Xcode")
        case .device:
            return SetupStep(kind: kind, title: "iPhone connected",
                summary: "Connect your iPhone once over USB so the Mac can install to it.",
                instructions: [
                    "Plug your iPhone into the Mac with a cable",
                    "On the phone, tap Trust and enter your passcode, then re-check."])
        case .developerMode:
            return SetupStep(kind: kind, title: "Developer Mode",
                summary: "iOS requires Developer Mode to run apps you build yourself.",
                instructions: [
                    "On iPhone: Settings → Privacy & Security",
                    "Scroll to the bottom → Developer Mode → On",
                    "The phone restarts; confirm with your passcode, then re-check."])
        case .install:
            return SetupStep(kind: kind, title: "Install Oops",
                summary: "Build Oops, sign it for your device, and install it — all automatic.",
                actionTitle: "Install Oops")
        case .trust:
            return SetupStep(kind: kind, title: "Trust Oops on your iPhone",
                summary: "A one-time tap so iOS will launch an app signed by your own Apple ID.",
                instructions: [
                    "On iPhone: Settings → General → VPN & Device Management",
                    "Under Developer App, tap your Apple ID profile → Trust, then re-check."])
        }
    }

    private func update(_ kind: SetupStep.Kind, _ mutate: (inout SetupStep) -> Void) {
        guard let i = steps.firstIndex(where: { $0.kind == kind }) else { return }
        mutate(&steps[i])
    }

    private func appendLog(_ line: String) { log += line + "\n" }

    // MARK: Orchestration

    /// Runs the checks top-to-bottom, stopping at the first step that needs the user.
    func refresh() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        for kind in SetupStep.Kind.allCases {
            update(kind) { if $0.state != .done { $0.state = .checking } }
            let done = await check(kind)
            if !done {
                // Leave the rest pending.
                for later in SetupStep.Kind.allCases where stepIndex(later) > stepIndex(kind) {
                    update(later) { if $0.state != .done { $0.state = .pending; $0.detail = "" } }
                }
                return
            }
        }
    }

    private func stepIndex(_ kind: SetupStep.Kind) -> Int {
        SetupStep.Kind.allCases.firstIndex(of: kind) ?? 0
    }

    /// Returns true if the step is satisfied.
    @discardableResult
    private func check(_ kind: SetupStep.Kind) async -> Bool {
        switch kind {
        case .xcode: return await checkXcode()
        case .account: return await checkAccount()
        case .device: return await checkDevice()
        case .developerMode: return await checkDeveloperMode()
        case .install: return await checkInstalled()
        case .trust: return await checkTrust()
        }
    }

    // MARK: Individual checks

    private func checkXcode() async -> Bool {
        let r = await Shell.run("xcodebuild -version")
        if r.succeeded, r.contains("Xcode") {
            let version = r.output.split(separator: "\n").first.map(String.init) ?? "Xcode"
            update(.xcode) { $0.state = .done; $0.detail = version }
            return true
        }
        update(.xcode) { $0.state = .needsAction; $0.detail = "Xcode not found." }
        return false
    }

    private func checkAccount() async -> Bool {
        let id = await Shell.run("defaults read com.apple.dt.Xcode IDEProvisioningTeamManagerLastSelectedTeamID")
        let team = id.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.succeeded, !team.isEmpty, !team.contains("does not exist") {
            teamID = team
            let nameResult = await Shell.run("defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | grep -m1 teamName")
            let name = SetupParse.firstMatch("\"([^\"]+)\"", in: nameResult.output)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? "Personal Team"
            teamName = name
            update(.account) { $0.state = .done; $0.detail = "\(name) · \(team)" }
            return true
        }
        update(.account) { $0.state = .needsAction; $0.detail = "No Apple ID signed into Xcode yet." }
        return false
    }

    private func checkDevice() async -> Bool {
        let list = await Shell.run("xcrun devicectl list devices")
        let coreID = SetupParse.firstMatch(
            "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}",
            in: list.output)
        let connectediPhone = list.output.split(separator: "\n").first {
            $0.contains("iPhone") && ($0.contains("available") || $0.contains("connected"))
        }
        guard let coreID, let line = connectediPhone else {
            update(.device) { $0.state = .needsAction; $0.detail = "No iPhone detected." }
            return false
        }
        let name = line.split(separator: "  ").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? "iPhone"
        let model = SetupParse.firstMatch("iPhone[0-9]+,[0-9]+", in: String(line)) ?? ""

        let trace = await Shell.run("xcrun xctrace list devices")
        let traceLine = trace.output.split(separator: "\n").first { $0.contains("iPhone") && !$0.contains("Simulator") } ?? ""
        let buildUDID = SetupParse.firstMatch("[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}", in: String(traceLine)) ?? ""
        let version = SetupParse.firstMatch("\\(([0-9]+\\.[0-9]+(\\.[0-9]+)?)\\)", in: String(traceLine))?
            .trimmingCharacters(in: CharacterSet(charactersIn: "()")) ?? "?"

        guard !buildUDID.isEmpty else {
            update(.device) { $0.state = .needsAction; $0.detail = "iPhone seen but not ready — unlock it and re-check." }
            return false
        }
        device = DeviceInfo(name: name, model: model, iosVersion: version, buildUDID: buildUDID, coreDeviceID: coreID)
        update(.device) { $0.state = .done; $0.detail = "\(name) · iOS \(version)" }
        return true
    }

    private func checkDeveloperMode() async -> Bool {
        let r = await Shell.run("xcodebuild -showdestinations -project Oops.xcodeproj -scheme \(scheme)", in: projectDir)
        if SetupParse.developerModeEnabled(in: r.output) {
            update(.developerMode) { $0.state = .done; $0.detail = "Enabled" }
            return true
        }
        update(.developerMode) { $0.state = .needsAction; $0.detail = "Developer Mode is off on your iPhone." }
        return false
    }

    private func checkInstalled() async -> Bool {
        guard let device else { return false }
        let r = await Shell.run("xcrun devicectl device info apps --device \(device.coreDeviceID)")
        if r.contains(bundleID) {
            update(.install) { $0.state = .done; $0.detail = "Installed on \(device.name)" }
            return true
        }
        update(.install) { $0.state = .needsAction; $0.detail = "Not installed yet." }
        return false
    }

    private func checkTrust() async -> Bool {
        guard let device else { return false }
        let r = await Shell.run("xcrun devicectl device process launch --device \(device.coreDeviceID) \(bundleID)")
        if r.contains("not been explicitly trusted") {
            update(.trust) { $0.state = .needsAction; $0.detail = "Profile not trusted yet." }
            return false
        }
        update(.trust) { $0.state = .done; $0.detail = "Trusted — Oops launches." }
        return true
    }

    // MARK: Actions

    func performAction(_ kind: SetupStep.Kind) async {
        switch kind {
        case .xcode:
            _ = await Shell.run("open -a 'App Store' macappstores://apps.apple.com/app/xcode/id497799835")
            await refresh()
        case .account:
            _ = await Shell.run("open -a Xcode")
        case .install:
            await installOnDevice()
        default:
            await refresh()
        }
    }

    private func installOnDevice() async {
        guard let device, let teamID else {
            update(.install) { $0.state = .failed("Missing device or team — re-check earlier steps.") }
            return
        }
        isRunning = true
        defer { isRunning = false }
        update(.install) { $0.state = .running; $0.detail = "Building & signing…" }
        appendLog("→ Building Oops for \(device.name)…")

        let build = await Shell.run(
            "xcodebuild -project Oops.xcodeproj -scheme \(scheme) "
            + "-destination 'platform=iOS,id=\(device.buildUDID)' -configuration Debug "
            + "-allowProvisioningUpdates DEVELOPMENT_TEAM=\(teamID) "
            + "-derivedDataPath build_device build",
            in: projectDir)
        guard build.contains("BUILD SUCCEEDED") else {
            update(.install) { $0.state = .failed("Build failed — see log.") }
            appendLog(String(build.output.suffix(1500)))
            return
        }
        appendLog("✓ Build succeeded. Installing…")
        update(.install) { $0.detail = "Installing to \(device.name)…" }

        let app = "build_device/Build/Products/Debug-iphoneos/Oops.app"
        let install = await Shell.run(
            "xcrun devicectl device install app --device \(device.coreDeviceID) \(app)", in: projectDir)
        guard install.succeeded else {
            update(.install) { $0.state = .failed("Install failed — see log.") }
            appendLog(String(install.output.suffix(1000)))
            return
        }
        appendLog("✓ Installed.")
        update(.install) { $0.state = .done; $0.detail = "Installed on \(device.name)" }
        // Roll straight into the trust check.
        update(.trust) { $0.state = .checking }
        _ = await checkTrust()
    }
}
