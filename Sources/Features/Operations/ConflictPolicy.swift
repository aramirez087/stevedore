import Core
import Foundation

// MARK: - ConflictResolution

/// The concrete outcome of resolving a conflict between a source and a destination path.
///
/// Distinct from `Core.ConflictPolicy` (which is the declarative input) — this
/// is the imperative result after policy application, including the new path
/// when renaming.
public enum ConflictResolution: Sendable, Equatable {
    case skip
    case replace
    /// Rename the destination: appends " (2)", " (3)", … until a unique path is found.
    case renameWithSuffix
}

// MARK: - ConflictResolver

/// Actor that maps `Core.ConflictPolicy` values to `ConflictResolution` outcomes.
///
/// For `.ask` policy the call suspends via `CheckedContinuation` until the UI
/// calls `provide(resolution:for:)`. No busy-waiting.
public actor ConflictResolver {
    private var pendingAsks: [FilePath: CheckedContinuation<ConflictResolution, Never>] = [:]

    public init() {}

    /// Resolve a conflict between `source` and an existing `destination`.
    ///
    /// - Returns immediately for `.skip`, `.overwrite`, and `.rename`.
    /// - Suspends for `.ask` until `provide(resolution:for:)` is called.
    public func resolve(
        source: FilePath,
        destination: FilePath,
        policy: ConflictPolicy
    ) async -> ConflictResolution {
        switch policy {
        case .skip:
            .skip
        case .overwrite:
            .replace
        case .rename:
            .renameWithSuffix
        case .ask:
            await withCheckedContinuation { continuation in
                // If a previous `.ask` for the same source is already waiting,
                // replace it (documented limitation — only one ask per source).
                if let existing = self.pendingAsks[source] {
                    existing.resume(returning: .replace)
                }
                self.pendingAsks[source] = continuation
            }
        }
    }

    /// Called by the UI to unblock a suspended `.ask` for `source`.
    ///
    /// No-ops if the source is not currently waiting.
    public func provide(resolution: ConflictResolution, for source: FilePath) {
        guard let continuation = self.pendingAsks.removeValue(forKey: source) else {
            return
        }
        continuation.resume(returning: resolution)
    }

    /// Generate a unique destination path by appending " (N)" to the stem.
    ///
    /// N starts at 2 and increments until the result is not in `existingPaths`.
    public static func uniquePath(
        for destination: FilePath,
        existingPaths: Set<FilePath>
    ) -> FilePath {
        guard existingPaths.contains(destination) else { return destination }
        guard let name = destination.lastComponent, let parent = destination.parent else {
            return destination
        }

        let (stem, ext) = Self.splitStemExtension(name)
        var index = 2
        while true {
            let candidate = if ext.isEmpty {
                "\(stem) (\(index))"
            } else {
                "\(stem) (\(index)).\(ext)"
            }
            let candidatePath = parent.appending(candidate)
            if !existingPaths.contains(candidatePath) {
                return candidatePath
            }
            index += 1
        }
    }

    // MARK: Private

    private static func splitStemExtension(_ name: String) -> (stem: String, ext: String) {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return (name, "")
        }
        let stem = String(name[name.startIndex ..< dot])
        let ext = String(name[name.index(after: dot)...])
        return (stem, ext)
    }
}
