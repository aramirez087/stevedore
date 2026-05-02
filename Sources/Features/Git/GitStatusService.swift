import Core
import Foundation

/// Concrete `GitStatusProvider` that shells out to `/usr/bin/git`.
///
/// Results are cached per repository and invalidated automatically via FSEvents
/// whenever any file in the working tree changes.
public actor GitStatusService: GitStatusProvider {
    private let cache: GitStatusCache

    public init(cache: GitStatusCache = GitStatusCache()) {
        self.cache = cache
    }

    // MARK: - GitStatusProvider

    public func status(under directory: FilePath) async throws -> [GitFileStatus] {
        guard let repoRoot = RepositoryDetector.findRoot(for: directory) else {
            return []
        }

        let root = repoRoot
        let allStatuses = try await cache.getOrFetch(repoRoot: root) {
            try await Self.fetchStatuses(repoRoot: root)
        }

        return allStatuses.filter { $0.path.posixString.hasPrefix(directory.posixString) }
    }

    public func repositoryRoot(for path: FilePath) async -> FilePath? {
        RepositoryDetector.findRoot(for: path)
    }

    // MARK: - Private

    private static func fetchStatuses(repoRoot: FilePath) async throws -> [GitFileStatus] {
        let result = try await GitProcess.run(
            arguments: [
                "status",
                "--porcelain=v2",
                "-z",
                "--untracked-files=all",
                "--ignored=matching",
            ],
            workingDirectory: URL(fileURLWithPath: repoRoot.posixString, isDirectory: true)
        )
        guard result.exitCode == 0 else {
            throw GitError.nonZeroExit(code: result.exitCode)
        }
        return GitStatusParser.parse(result.stdout, repoRoot: repoRoot)
    }
}
