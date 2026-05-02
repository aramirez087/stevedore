import Core
import Foundation

// MARK: - AssociatedFile

/// A candidate file or directory that may belong to the app being uninstalled.
public struct AssociatedFile: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let sizeInBytes: Int64
    public let modificationDate: Date?
    public let scoreResult: ScoreResult
    /// Whether this path is under a system-owned root (`/Library/…`).
    public let requiresAdmin: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        sizeInBytes: Int64,
        modificationDate: Date?,
        scoreResult: ScoreResult,
        requiresAdmin: Bool
    ) {
        self.id = id
        self.url = url
        self.sizeInBytes = sizeInBytes
        self.modificationDate = modificationDate
        self.scoreResult = scoreResult
        self.requiresAdmin = requiresAdmin
    }

    /// Convenience accessor.
    public var confidence: ConfidenceLevel {
        self.scoreResult.confidenceLevel
    }

    public var reason: String {
        self.scoreResult.reasons.joined(separator: "; ")
    }
}

// MARK: - AssociatedFilesScanner

/// Walks `SearchPaths.all`, scores each top-level entry against the provided
/// `AppMetadata`, and returns `[AssociatedFile]` above a minimum threshold.
///
/// Only the **direct children** of each search-path root are examined —
/// recursing into every subdirectory would be prohibitively slow.  For
/// container directories (which are already per-app) a single entry matches
/// and is included as a unit.
public struct AssociatedFilesScanner: Sendable {
    private let scorer: MatchScorer
    private let minimumScore: Double
    private let searchPaths: [SearchPath]

    public init(
        scorer: MatchScorer = MatchScorer(),
        minimumScore: Double = MatchScorer.mediumCutoff,
        searchPaths: [SearchPath] = SearchPaths.all
    ) {
        self.scorer = scorer
        self.minimumScore = minimumScore
        self.searchPaths = searchPaths
    }

    // MARK: Public API

    /// Scan all search paths and return scored candidates.
    ///
    /// This method performs synchronous I/O; call it from a background
    /// context (e.g. inside a `Task { }`) to avoid blocking the main actor.
    public func scan(for metadata: AppMetadata) -> [AssociatedFile] {
        var results: [AssociatedFile] = []
        let fm = FileManager.default

        for searchPath in self.searchPaths {
            guard fm.fileExists(atPath: searchPath.url.path) else { continue }

            let contents: [URL]
            do {
                contents = try fm.contentsOfDirectory(
                    at: searchPath.url,
                    includingPropertiesForKeys: [
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .isDirectoryKey,
                        .totalFileSizeKey,
                    ],
                    options: [.skipsHiddenFiles]
                )
            } catch {
                continue
            }

            for url in contents {
                let scoreResult = self.scorer.score(url, against: metadata)
                guard scoreResult.score >= self.minimumScore else { continue }

                let attrs = try? url.resourceValues(forKeys: [
                    .totalFileSizeKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                ])
                let size = Int64(attrs?.totalFileSize ?? attrs?.fileSize ?? 0)
                let modified = attrs?.contentModificationDate

                results.append(AssociatedFile(
                    url: url,
                    sizeInBytes: size,
                    modificationDate: modified,
                    scoreResult: scoreResult,
                    requiresAdmin: searchPath.kind == .system
                ))
            }
        }

        // Stable sort: highest score first, then by path
        return results.sorted {
            if $0.scoreResult.score != $1.scoreResult.score {
                return $0.scoreResult.score > $1.scoreResult.score
            }
            return $0.url.path < $1.url.path
        }
    }
}
