import Foundation

/// Stateless wrapper around `Foundation.Process` that runs git with a
/// fixed, minimal environment and an enforced timeout.
public enum GitProcess: Sendable {
    public static let executablePath = "/usr/bin/git"

    /// Keys inherited from the calling process's environment.
    private static let allowedEnvKeys: Set<String> = [
        "HOME", "USER", "TMPDIR", "LANG", "LC_ALL",
        "GIT_SSH", "GIT_SSH_COMMAND", "SSH_AUTH_SOCK",
    ]

    /// Fixed injections that suppress interactive prompts and pagers.
    private static let injectedEnv: [String: String] = [
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_PAGER": "cat",
        "PAGER": "cat",
    ]

    public struct Result: Sendable {
        public let exitCode: Int32
        public let stdout: Data
        public let stderr: Data
    }

    /// Runs `git` with the given arguments.
    ///
    /// - Parameters:
    ///   - arguments: Arguments to pass after the git executable.
    ///   - workingDirectory: URL of the directory git should treat as CWD.
    ///   - timeoutSeconds: Maximum wall-clock seconds before the process is
    ///     killed and `GitError.timeout` is thrown.
    public static func run(
        arguments: [String],
        workingDirectory: URL,
        timeoutSeconds: Double = 30
    ) async throws -> Result {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw GitError.gitNotFound
        }

        // Build whitelisted environment.
        let callerEnv = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]
        for key in allowedEnvKeys {
            if let value = callerEnv[key] {
                env[key] = value
            }
        }
        for (key, value) in injectedEnv {
            env[key] = value
        }

        // `ProcessBox` transfers ownership of the Process across task boundaries.
        // Single-owner pattern: created here, launched in the detached task,
        // terminated (if needed) from the timeout task. @unchecked Sendable is
        // justified because only one task at a time accesses the Process after
        // the structured-concurrency handoff.
        final class ProcessBox: @unchecked Sendable {
            let process: Process
            init(_ process: Process) { self.process = process }
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = arguments
        proc.currentDirectoryURL = workingDirectory
        proc.environment = env
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        let box = ProcessBox(proc)

        return try await withThrowingTaskGroup(of: Result.self) { group in
            // Task 1: launch and wait for exit.
            group.addTask {
                try await Task.detached(priority: .utility) {
                    let p = box.process
                    try p.run()
                    p.waitUntilExit()
                    let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    return Result(exitCode: p.terminationStatus, stdout: stdout, stderr: stderr)
                }.value
            }

            // Task 2: timeout guard.
            group.addTask {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                box.process.terminate()
                throw GitError.timeout
            }

            // Take the first result (process finish or timeout).
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
