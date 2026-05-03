import Core
import Foundation

/// Parses `git status --porcelain=v2 -z` NUL-delimited output into an array
/// of `GitFileStatus` values.
///
/// Unknown or malformed records are silently skipped; the parser never throws.
public enum GitStatusParser: Sendable {
    /// Parses raw bytes from `git status --porcelain=v2 -z`.
    ///
    /// - Parameters:
    ///   - data: Raw stdout bytes from the git process.
    ///   - repoRoot: Absolute repo working-tree root used to resolve relative paths.
    /// - Returns: One entry per tracked / untracked / ignored file.
    public static func parse(_ data: Data, repoRoot: FilePath) -> [GitFileStatus] {
        guard !data.isEmpty else { return [] }
        let tokens = data.split(separator: 0, omittingEmptySubsequences: false).map {
            String(bytes: $0, encoding: .utf8) ?? ""
        }
        var results: [GitFileStatus] = []
        var cursor = 0
        while cursor < tokens.count {
            let (entry, consumed) = self.parseSingleToken(tokens[cursor], repoRoot: repoRoot)
            if let entry { results.append(entry) }
            cursor += consumed
        }
        return results
    }

    // MARK: - Private helpers

    /// Dispatches a single NUL-delimited token to the appropriate sub-parser.
    private static func parseSingleToken(_ token: String, repoRoot: FilePath) -> (GitFileStatus?, Int) {
        guard !token.isEmpty else { return (nil, 1) }
        let parts = token.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            .map(String.init)
        guard let prefix = parts.first else { return (nil, 1) }
        switch prefix {
        case "#": return (nil, 1)
        case "1": return (self.parseOrdinary(token, repoRoot: repoRoot), 1)
        case "2": return (self.parseRenamed(token, repoRoot: repoRoot), 2)
        case "u": return (self.parseUnmerged(token, repoRoot: repoRoot), 1)
        case "?": return (self.parseSimplePath(parts, state: .untracked, repoRoot: repoRoot), 1)
        case "!": return (self.parseSimplePath(parts, state: .ignored, repoRoot: repoRoot), 1)
        default: return (nil, 1)
        }
    }

    /// Parses `? path` / `! path` records where index and worktree state are identical.
    private static func parseSimplePath(
        _ parts: [String],
        state: GitFileStatus.WorktreeState,
        repoRoot: FilePath
    ) -> GitFileStatus? {
        guard parts.count == 2, let pathToken = parts.last else { return nil }
        let path = repoRoot.appending(posix: pathToken)
        return GitFileStatus(path: path, indexState: state, worktreeState: state)
    }

    /// Extracts index and worktree states from the two-character XY field.
    private static func xyStates(from fields: [String])
        -> (index: GitFileStatus.WorktreeState, worktree: GitFileStatus.WorktreeState)? {
        let xy = fields[1]
        guard xy.count == 2,
              let xScalar = xy.unicodeScalars.first,
              let yScalar = xy.unicodeScalars.dropFirst().first else { return nil }
        return (self.statusState(xScalar.value), self.statusState(yScalar.value))
    }

    /// Parses a type-1 (ordinary changed) record.
    /// Format: `1 XY sub mH mI mW hH hI path`
    private static func parseOrdinary(_ token: String, repoRoot: FilePath) -> GitFileStatus? {
        let fields = token.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 9, let states = xyStates(from: fields) else { return nil }
        let relativePath = fields[8...].joined(separator: " ")
        let path = repoRoot.appending(posix: relativePath)
        return GitFileStatus(path: path, indexState: states.index, worktreeState: states.worktree)
    }

    /// Parses a type-2 (renamed/copied) record.
    /// Format: `2 XY sub mH mI mW hH hI X<score> path`  (next NUL token = origPath)
    /// We use the *new* path and skip origPath.
    private static func parseRenamed(_ token: String, repoRoot: FilePath) -> GitFileStatus? {
        let fields = token.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 10, let states = xyStates(from: fields) else { return nil }
        let relativePath = fields[9...].joined(separator: " ")
        let path = repoRoot.appending(posix: relativePath)
        return GitFileStatus(path: path, indexState: states.index, worktreeState: states.worktree)
    }

    /// Parses a type-u (unmerged) record.
    /// Format: `u XY sub m1 m2 m3 mW h1 h2 h3 path`
    private static func parseUnmerged(_ token: String, repoRoot: FilePath) -> GitFileStatus? {
        let fields = token.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 11 else { return nil }
        let relativePath = fields[10...].joined(separator: " ")
        let path = repoRoot.appending(posix: relativePath)
        return GitFileStatus(path: path, indexState: .conflicted, worktreeState: .conflicted)
    }

    /// Maps a single porcelain v2 status character to a `WorktreeState`.
    private static func statusState(_ scalar: UInt32) -> GitFileStatus.WorktreeState {
        switch scalar {
        case UInt32(("." as UnicodeScalar).value): .unmodified
        case UInt32(("M" as UnicodeScalar).value): .modified
        case UInt32(("T" as UnicodeScalar).value): .typeChanged
        case UInt32(("A" as UnicodeScalar).value): .added
        case UInt32(("D" as UnicodeScalar).value): .deleted
        case UInt32(("R" as UnicodeScalar).value): .renamed
        case UInt32(("C" as UnicodeScalar).value): .copied
        case UInt32(("U" as UnicodeScalar).value): .conflicted
        default: .unmodified
        }
    }
}
