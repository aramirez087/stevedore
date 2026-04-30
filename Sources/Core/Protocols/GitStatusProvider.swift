/// Wraps `git status --porcelain=v2` so the file list can render git
/// indicators inline.
public protocol GitStatusProvider: Sendable {
    /// Status of every tracked / untracked file under `directory`.
    func status(under directory: FilePath) async throws -> [GitFileStatus]

    /// Walks up from `path` and returns the repository root, if any.
    func repositoryRoot(for path: FilePath) async -> FilePath?
}
