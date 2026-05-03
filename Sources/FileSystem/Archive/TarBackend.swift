import Core
import Foundation

/// Archive backend for `.tar`, `.tar.gz`, and `.tar.bz2` that shells out to
/// `/usr/bin/tar`. `/usr/bin/tar` on macOS is BSD tar; only POSIX-portable
/// flags are used.
///
/// A `TarProcessRunner` actor owns the `Process` so its reference never
/// crosses isolation boundaries under Swift 6 strict concurrency.
public struct TarBackend: ArchiveBackend {
    public let format: ArchiveFormat

    /// - Throws: `StevedoreError.invalidArgument` for non-tar formats.
    public init(format: ArchiveFormat) throws {
        switch format {
        case .tar, .tarGzip, .tarBzip2:
            self.format = format
        case .zip:
            throw StevedoreError.invalidArgument("TarBackend does not handle .zip archives")
        }
    }

    func listEntries(at archive: URL) async throws -> [ArchiveEntry] {
        let flag = self.listFlag
        let lines = try await TarProcessRunner.run(
            args: ["tar", flag, archive.path],
            archivePath: archive.path
        )
        var entries: [ArchiveEntry] = []
        for line in lines where !line.isEmpty {
            // tar -tf may include a trailing "/" on directory entries.
            let rawPath = line.hasSuffix("/") ? String(line.dropLast()) : line
            guard !rawPath.isEmpty else { continue }
            let components = try validateAndSplitEntryPath(rawPath)
            let kind: FileKind = line.hasSuffix("/") ? .directory : .regularFile
            entries.append(ArchiveEntry(
                pathComponents: components,
                kind: kind,
                sizeInBytes: nil,
                modificationDate: nil,
                permissions: nil,
                symbolicLinkTarget: nil
            ))
        }
        return entries
    }

    func extractAll(
        from archive: URL,
        to destination: URL,
        progress: (any OperationProgressReporting)?
    ) async throws {
        // Validate all paths before writing a single byte.
        let entries = try await self.listEntries(at: archive)
        let total = Int64(entries.count)
        var done: Int64 = 0

        let flag = self.extractFlag
        let lines = try await TarProcessRunner.run(
            args: ["tar", flag, archive.path, "-C", destination.path],
            archivePath: archive.path
        )
        for line in lines where !line.isEmpty {
            done += 1
            if let reporter = progress {
                await reporter.report(Progress(
                    bytesDone: done,
                    bytesTotal: total,
                    phase: .transferring,
                    currentItemDisplayName: line
                ))
            }
        }
    }

    // MARK: - Private

    private var listFlag: String {
        switch self.format {
        case .tar: "-tf"
        case .tarGzip: "-tzf"
        case .tarBzip2: "-tjf"
        case .zip: "-tf"
        }
    }

    private var extractFlag: String {
        switch self.format {
        case .tar: "-xvf"
        case .tarGzip: "-xvzf"
        case .tarBzip2: "-xvjf"
        case .zip: "-xvf"
        }
    }
}

// MARK: - TarProcessRunner

/// Actor that owns and manages a single `/usr/bin/tar` subprocess, providing
/// a safe concurrency boundary for the non-`Sendable` `Process` type.
private actor TarProcessRunner {
    private var process: Process?

    static func run(args: [String], archivePath: String) async throws -> [String] {
        let runner = TarProcessRunner()
        return try await runner.execute(args: args)
    }

    private func terminateProcess() {
        self.process?.terminate()
    }

    private func execute(args: [String]) async throws -> [String] {
        let proc = Process()
        self.process = proc
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = args
        proc.currentDirectoryURL = URL(fileURLWithPath: "/")
        proc.qualityOfService = .userInitiated

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try proc.run()
                } catch {
                    continuation.resume(throwing: StevedoreError.archive(
                        .corruptedEntry(detail: "failed to launch tar: \(error.localizedDescription)")
                    ))
                    return
                }

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()

                if proc.terminationStatus != 0 {
                    let detail = String(data: stderrData, encoding: .utf8) ?? "unknown tar error"
                    continuation.resume(throwing: StevedoreError.archive(
                        .corruptedEntry(detail: "tar exited \(proc.terminationStatus): \(detail)")
                    ))
                    return
                }

                let output = String(data: stdoutData, encoding: .utf8) ?? ""
                let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                continuation.resume(returning: lines)
            }
        } onCancel: {
            // Process.terminate() is documented thread-safe; deliver via a new
            // unstructured task so the call crosses the actor isolation boundary.
            Task { await self.terminateProcess() }
        }
    }
}
