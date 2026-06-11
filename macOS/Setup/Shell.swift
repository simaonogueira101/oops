import Foundation

/// Result of running a shell command.
struct ShellResult: Sendable {
    let output: String
    let exitCode: Int32
    var succeeded: Bool { exitCode == 0 }
    func contains(_ needle: String) -> Bool { output.localizedCaseInsensitiveContains(needle) }
}

/// Runs command-line tools (xcodebuild, xcrun, defaults, …) for the setup flow.
/// The macOS app is unsandboxed, so spawning processes is allowed.
enum Shell {
    static func run(_ command: String, in directory: String? = nil) async -> ShellResult {
        await withCheckedContinuation { (continuation: CheckedContinuation<ShellResult, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                if let directory { process.currentDirectoryURL = URL(fileURLWithPath: directory) }

                // Merge stdout + stderr into one pipe to avoid two-pipe deadlocks.
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ShellResult(
                        output: "Failed to launch: \(error.localizedDescription)", exitCode: -1))
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: ShellResult(
                    output: String(decoding: data, as: UTF8.self),
                    exitCode: process.terminationStatus))
            }
        }
    }
}
