import Core
import Foundation

/// Orchestrates extraction of an archive into a target directory.
///
/// Extraction uses a staging directory so cancellation never leaves
/// half-written files in the final target. Entries are validated against
/// path traversal before any disk write occurs.
public struct ArchiveExtractor: Sendable {
    private let progressReporter: (any OperationProgressReporting)?
    private let conflictPolicy: ConflictPolicy

    public init(
        progress: (any OperationProgressReporting)? = nil,
        conflictPolicy: ConflictPolicy = .overwrite
    ) {
        self.progressReporter = progress
        self.conflictPolicy = conflictPolicy
    }

    /// Extract `archive` into `target`.
    ///
    /// - Returns: summary of what was extracted.
    /// - Throws: `StevedoreError.cancelled` on cooperative cancellation,
    ///   `StevedoreError.archive(.unsupportedFormat)` for unrecognised formats,
    ///   or `StevedoreError.archive(.corruptedEntry)` on traversal attempts.
    public func extract(archive: URL, to target: URL) async throws -> ArchiveExtractionResult {
        // 1. Detect format.
        guard let format = await ArchiveDetector.detect(at: archive) else {
            throw StevedoreError.archive(.unsupportedFormat)
        }

        // 2. Pick backend and validate all paths upfront — no disk I/O yet.
        let backend = try Self.makeBackend(format: format)
        let entries = try await backend.listEntries(at: archive)

        // 3. Compute total bytes for progress reporting.
        let totalBytes = entries.compactMap(\.sizeInBytes).reduce(0, +)
        let bytesTotal: Int64? = totalBytes > 0 ? totalBytes : nil

        // 4. Create staging directory; the defer ensures cleanup even on cancel/throw.
        let stagingURL = target.appendingPathComponent(
            ".stevedore-extract-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)

        do {
            // 5. Extract into staging.
            try await withTaskCancellationHandler {
                try await backend.extractAll(from: archive, to: stagingURL, progress: nil)
            } onCancel: {
                // Cleanup happens in the outer defer.
            }

            // 6. Report staging complete.
            await self.progressReporter?.report(Progress(
                bytesDone: totalBytes,
                bytesTotal: bytesTotal,
                phase: .finalizing
            ))

            // 7. Reconcile staging → target.
            var reconciled = 0
            var bytesReconciled: Int64 = 0
            for entry in entries {
                try Task.checkCancellation()
                let srcURL = stagingURL.appendingPathComponent(entry.relativePath)
                let dstURL = target.appendingPathComponent(entry.relativePath)

                if entry.kind == .directory {
                    try FileManager.default.createDirectory(at: dstURL, withIntermediateDirectories: true)
                    continue
                }

                let parentDir = dstURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

                let exists = FileManager.default.fileExists(atPath: dstURL.path)
                if exists {
                    switch self.conflictPolicy {
                    case .skip:
                        continue
                    case .overwrite, .ask, .rename:
                        // .ask and .rename fall back to .overwrite in MVP.
                        try FileManager.default.removeItem(at: dstURL)
                    }
                }
                try FileManager.default.moveItem(at: srcURL, to: dstURL)
                reconciled += 1
                bytesReconciled += entry.sizeInBytes ?? 0

                await self.progressReporter?.report(Progress(
                    bytesDone: bytesReconciled,
                    bytesTotal: bytesTotal,
                    phase: .transferring,
                    currentItemDisplayName: entry.pathComponents.last
                ))
            }

            // 8. Final progress.
            await self.progressReporter?.report(Progress(
                bytesDone: bytesReconciled,
                bytesTotal: bytesTotal,
                phase: .completed
            ))

            // 9. Remove staging dir (might be empty after moves).
            try? FileManager.default.removeItem(at: stagingURL)
            return ArchiveExtractionResult(entriesExtracted: reconciled, bytesProcessed: bytesReconciled)

        } catch is CancellationError {
            try? FileManager.default.removeItem(at: stagingURL)
            throw StevedoreError.cancelled
        } catch let error as StevedoreError where error == .cancelled {
            try? FileManager.default.removeItem(at: stagingURL)
            throw error
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            throw error
        }
    }

    // MARK: - Private

    private static func makeBackend(format: ArchiveFormat) throws -> any ArchiveBackend {
        switch format {
        case .zip: ZipBackend()
        case .tar, .tarGzip, .tarBzip2: try TarBackend(format: format)
        }
    }
}
