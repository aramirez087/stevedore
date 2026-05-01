import Core
import Foundation

// MARK: - FolderComparator

/// Walks two `FileSystemProvider` roots concurrently and produces `Difference` rows.
///
/// Both sides are enumerated in parallel via `withThrowingTaskGroup`. Ignore globs
/// from `SyncOptions` are applied to relative POSIX paths before comparison.
public actor FolderComparator {
    private let leftProvider: any FileSystemProvider
    private let rightProvider: any FileSystemProvider
    private let options: SyncOptions

    public init(
        leftProvider: any FileSystemProvider,
        rightProvider: any FileSystemProvider,
        options: SyncOptions = .default
    ) {
        self.leftProvider = leftProvider
        self.rightProvider = rightProvider
        self.options = options
    }

    /// Walk both roots and return the full difference list.
    ///
    /// - Parameters:
    ///   - leftRoot: Absolute path served by `leftProvider`.
    ///   - rightRoot: Absolute path served by `rightProvider`.
    /// - Returns: Sorted (by relative path) list of differences.
    public func compare(leftRoot: FilePath, rightRoot: FilePath) async throws -> [Difference] {
        let (leftItems, rightItems) = try await self.enumerateBothSides(
            leftRoot: leftRoot,
            rightRoot: rightRoot
        )

        var leftMap: [String: FileItem] = [:]
        for item in leftItems {
            guard let rel = item.path.relativePosix(to: leftRoot), !rel.isEmpty else { continue }
            guard !self.isIgnored(rel) else { continue }
            leftMap[rel] = item
        }

        var rightMap: [String: FileItem] = [:]
        for item in rightItems {
            guard let rel = item.path.relativePosix(to: rightRoot), !rel.isEmpty else { continue }
            guard !self.isIgnored(rel) else { continue }
            rightMap[rel] = item
        }

        var differences: [Difference] = []
        let allKeys = Set(leftMap.keys).union(Set(rightMap.keys)).sorted()

        for key in allKeys {
            let left = leftMap[key]
            let right = rightMap[key]
            let relPath = FilePath(scheme: leftRoot.scheme, posix: key)

            let diff: Difference
            switch (left, right) {
            case (let l?, nil):
                diff = Difference(relativePath: relPath, status: .leftOnly, leftItem: l, rightItem: nil)
            case (nil, let r?):
                diff = Difference(relativePath: relPath, status: .rightOnly, leftItem: nil, rightItem: r)
            case (let l?, let r?):
                let status = try await self.compareItems(left: l, leftRoot: leftRoot, right: r, rightRoot: rightRoot)
                diff = Difference(relativePath: relPath, status: status, leftItem: l, rightItem: r)
            case (nil, nil):
                continue
            }
            differences.append(diff)
        }

        return differences
    }

    // MARK: Private — enumeration

    private func enumerateBothSides(
        leftRoot: FilePath,
        rightRoot: FilePath
    ) async throws -> (left: [FileItem], right: [FileItem]) {
        let enumerationOptions = EnumerationOptions(includesHiddenFiles: true, isRecursive: true)
        let leftProv = self.leftProvider
        let rightProv = self.rightProvider

        return try await withThrowingTaskGroup(of: (Bool, [FileItem]).self) { group in
            group.addTask {
                let items = try await Self.enumerate(root: leftRoot, provider: leftProv, options: enumerationOptions)
                return (true, items)
            }
            group.addTask {
                let items = try await Self.enumerate(root: rightRoot, provider: rightProv, options: enumerationOptions)
                return (false, items)
            }
            var left: [FileItem] = []
            var right: [FileItem] = []
            for try await (isLeft, items) in group {
                if isLeft { left = items } else { right = items }
            }
            return (left, right)
        }
    }

    private static func enumerate(
        root: FilePath,
        provider: any FileSystemProvider,
        options: EnumerationOptions
    ) async throws -> [FileItem] {
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: root, options: options) {
            items.append(item)
        }
        return items
    }

    // MARK: Private — comparison

    private func isIgnored(_ relativePosix: String) -> Bool {
        self.options.ignoreGlobs.contains { pattern in
            GlobMatcher.matches(pattern: pattern, path: relativePosix, caseSensitive: true)
        }
    }

    private func compareItems(
        left: FileItem,
        leftRoot: FilePath,
        right: FileItem,
        rightRoot: FilePath
    ) async throws -> DifferenceStatus {
        if self.options.useDeepHash {
            return try await self.deepCompare(left: left, right: right)
        }
        return self.fastCompare(left: left, right: right)
    }

    private func fastCompare(left: FileItem, right: FileItem) -> DifferenceStatus {
        let leftSize = left.attributes.sizeInBytes
        let rightSize = right.attributes.sizeInBytes

        if let ls = leftSize, let rs = rightSize {
            if abs(ls - rs) > self.options.sizeTolerance { return .modified }
        } else if leftSize != nil || rightSize != nil {
            return .modified
        }

        let leftMtime = left.attributes.modificationDate
        let rightMtime = right.attributes.modificationDate

        if let lm = leftMtime, let rm = rightMtime {
            if abs(lm.timeIntervalSince(rm)) > self.options.mtimeTolerance { return .modified }
        } else if leftMtime != nil || rightMtime != nil {
            return .modified
        }

        return .matched
    }

    private func deepCompare(left: FileItem, right: FileItem) async throws -> DifferenceStatus {
        guard let leftReadable = self.leftProvider as? any SyncReadableProvider,
              let rightReadable = self.rightProvider as? any SyncReadableProvider
        else {
            throw StevedoreError.unsupported(
                "deep compare requires SyncReadableProvider conformance"
            )
        }

        let leftHash = try await HashStrategy.sha256(
            reading: leftReadable.readChunks(at: left.path, chunkSize: HashStrategy.defaultChunkSize)
        )
        let rightHash = try await HashStrategy.sha256(
            reading: rightReadable.readChunks(at: right.path, chunkSize: HashStrategy.defaultChunkSize)
        )

        return leftHash == rightHash ? .matched : .modified
    }
}
