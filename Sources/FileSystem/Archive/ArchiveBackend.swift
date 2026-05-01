import Core
import Foundation

/// Internal protocol implemented by format-specific archive backends.
///
/// Backends are stateless `Sendable` structs. Path-traversal validation is
/// performed inside `listEntries`; callers may assume that every returned
/// `ArchiveEntry` has safe, validated path components.
protocol ArchiveBackend: Sendable {
    var format: ArchiveFormat { get }

    /// List all entries in the archive. Validates paths and throws
    /// `StevedoreError.archive(.corruptedEntry)` on traversal attempts.
    func listEntries(at archive: URL) async throws -> [ArchiveEntry]

    /// Extract all entries into `destination`. Cooperates with Swift
    /// structured concurrency: implementations must check `Task.isCancelled`
    /// between entries and throw `CancellationError` when set.
    func extractAll(
        from archive: URL,
        to destination: URL,
        progress: (any OperationProgressReporting)?
    ) async throws
}
