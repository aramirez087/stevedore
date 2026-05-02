import Foundation

public actor AssociatedFilesScanner: AssociatedFilesScanning {
    private let userSearchPaths: [URL]
    private let systemSearchPaths: [URL]

    public init(
        userSearchPaths: [URL] = SearchPaths.userPaths,
        systemSearchPaths: [URL] = SearchPaths.systemPaths
    ) {
        self.userSearchPaths = userSearchPaths
        self.systemSearchPaths = systemSearchPaths
    }

    public func scan(for metadata: AppMetadata) async throws -> [AssociatedFile] {
        var results: [AssociatedFile] = []
        results += self.scanPaths(self.userSearchPaths, metadata: metadata, requiresAdmin: false)
        results += self.scanPaths(self.systemSearchPaths, metadata: metadata, requiresAdmin: true)
        return results.sorted { $0.confidence > $1.confidence }
    }

    private func scanPaths(_ paths: [URL], metadata: AppMetadata, requiresAdmin: Bool) -> [AssociatedFile] {
        var results: [AssociatedFile] = []
        for dir in paths {
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: []
            ) else { continue }
            for item in items {
                let (score, reason) = MatchScorer.score(url: item, metadata: metadata)
                guard score > 0.1 else { continue }
                guard let values = try? item.resourceValues(forKeys: [
                    .fileSizeKey,
                    .contentModificationDateKey,
                ]) else { continue }
                let size = Int64(values.fileSize ?? 0)
                let modified = values.contentModificationDate ?? Date.distantPast
                results.append(AssociatedFile(
                    url: item,
                    sizeInBytes: size,
                    lastModified: modified,
                    confidence: Confidence.from(score: score),
                    reason: reason,
                    requiresAdmin: requiresAdmin
                ))
            }
        }
        return results
    }
}
