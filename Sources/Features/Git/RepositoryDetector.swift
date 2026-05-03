import Core
import Foundation

/// Walks the filesystem ancestor chain to locate the git repository root for a
/// given path.
///
/// Only `.local` scheme paths are supported. All other schemes return `nil`.
/// Bare repositories (no working tree) return `nil` because there is no
/// working-tree status to report.
public enum RepositoryDetector: Sendable {
    /// Returns the working-tree root for `path`, or `nil` if `path` is not
    /// inside a git repository.
    public static func findRoot(for path: FilePath) -> FilePath? {
        guard path.scheme == .local else { return nil }

        var candidate = path
        while true {
            let dotGitPath = candidate.posixString + "/.git"
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: dotGitPath, isDirectory: &isDir)

            if exists {
                if isDir.boolValue {
                    // Normal repo: `.git` is a directory.
                    return candidate
                } else {
                    // Worktree linkfile: `.git` is a file beginning with `gitdir: <path>`.
                    // The working-tree root is the directory that contains the linkfile.
                    return candidate
                }
            }

            // Ascend to parent; stop at root.
            guard let parent = candidate.parent else { return nil }
            candidate = parent
        }
    }
}
