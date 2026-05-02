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

        // Split on NUL to produce a flat token array.
        let tokens = data.split(separator: 0, omittingEmptySubsequences: false).map {
            String(decoding: $0, as: UTF8.self)
        }

        var results: [GitFileStatus] = []
        var cursor = 0

        while cursor < tokens.count {
            let token = tokens[cursor]
            guard !token.isEmpty else { cursor += 1; continue }

            let parts = token.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                .map(String.init)
            guard let prefix = parts.first else { cursor += 1; continue }

            switch prefix {
            case "#":
                // Branch / header line — skip.
                cursor += 1

            case "1":
                // Ordinary changed entry: `1 XY sub mH mI mW hH hI path`
                if let entry = parseOrdinary(token, repoRoot: repoRoot) {
                    results.append(entry)
                }
                cursor += 1

            case "2":
                // Renamed / copied: consumes two tokens (`path` then `origPath`).
                if let entry = parseRenamed(token, repoRoot: repoRoot) {
                    results.append(entry)
                }
                cursor += 2

            case "u":
                // Unmerged: `u XY sub m1 m2 m3 mW h1 h2 h3 path`
                if let entry = parseUnmerged(token, repoRoot: repoRoot) {
                    results.append(entry)
                }
                cursor += 1

            case "?":
                // Untracked: `? path`
                if let pathToken = parts.last, parts.count == 2 {
                    let path = repoRoot.appending(posix: pathToken)
                    results.append(GitFileStatus(path: path, indexState: .untracked, worktreeState: .untracked))
                }
                cursor += 1

            case "!":
                // Ignored: `! path`
                if let pathToken = parts.last, parts.count == 2 {
                    let path = repoRoot.appending(posix: pathToken)
                    results.append(GitFileStatus(path: path, indexState: .ignored, worktreeState: .ignored))
                }
                cursor += 1

            default:
                cursor += 1
            }
        }

        return results
    }

    // MARK: - Private helpers

    /// Parses a type-1 (ordinary changed) record.
    /// Format: `1 XY sub mH mI mW hH hI path`
    private static func parseOrdinary(_ token: String, repoRoot: FilePath) -> GitFileStatus? {
        let fields = token.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        // Minimum fields: prefix, XY, sub, mH, mI, mW, hH, hI, path = 9
        guard fields.count >= 9 else { return nil }
        let xy = fields[1]
        guard xy.count == 2 else { return nil }
        let xChar = xy.unicodeScalars.first!.value
        let yChar = xy.unicodeScalars.dropFirst().first!.value
        let indexState = statusState(UInt32(xChar))
        let worktreeState = statusState(UInt32(yChar))
        let relativePath = fields[8...].joined(separator: " ")
        let path = repoRoot.appending(posix: relativePath)
        return GitFileStatus(path: path, indexState: indexState, worktreeState: worktreeState)
    }

    /// Parses a type-2 (renamed/copied) record.
    /// Format: `2 XY sub mH mI mW hH hI X<score> path`  (next NUL token = origPath)
    /// We use the *new* path and skip origPath.
    private static func parseRenamed(_ token: String, repoRoot: FilePath) -> GitFileStatus? {
        let fields = token.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        // Minimum fields: prefix, XY, sub, mH, mI, mW, hH, hI, score, path = 10
        guard fields.count >= 10 else { return nil }
        let xy = fields[1]
        guard xy.count == 2 else { return nil }
        let xChar = xy.unicodeScalars.first!.value
        let yChar = xy.unicodeScalars.dropFirst().first!.value
        let indexState = statusState(UInt32(xChar))
        let worktreeState = statusState(UInt32(yChar))
        let relativePath = fields[9...].joined(separator: " ")
        let path = repoRoot.appending(posix: relativePath)
        return GitFileStatus(path: path, indexState: indexState, worktreeState: worktreeState)
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
        case UInt32(("." as UnicodeScalar).value): return .unmodified
        case UInt32(("M" as UnicodeScalar).value): return .modified
        case UInt32(("T" as UnicodeScalar).value): return .typeChanged
        case UInt32(("A" as UnicodeScalar).value): return .added
        case UInt32(("D" as UnicodeScalar).value): return .deleted
        case UInt32(("R" as UnicodeScalar).value): return .renamed
        case UInt32(("C" as UnicodeScalar).value): return .copied
        case UInt32(("U" as UnicodeScalar).value): return .conflicted
        default: return .unmodified
        }
    }
}
