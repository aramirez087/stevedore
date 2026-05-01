import Foundation

/// The attribute by which a list of `FileItem`s can be sorted.
public enum FileItemSortKey: String, Sendable, Hashable, CaseIterable {
    case name
    case size
    case modified
    case kind
    case fileExtension
}

/// A fully-configured, stable sort descriptor for `FileItem` arrays.
public struct FileItemSortDescriptor: Sendable, Hashable {
    public let key: FileItemSortKey
    public let ascending: Bool
    public let directoriesFirst: Bool
    public let locale: Locale

    public init(
        key: FileItemSortKey,
        ascending: Bool = true,
        directoriesFirst: Bool = true,
        locale: Locale = .current
    ) {
        self.key = key
        self.ascending = ascending
        self.directoriesFirst = directoriesFirst
        self.locale = locale
    }

    // MARK: - Convenience statics

    public static let byName = Self(key: .name)
    public static let bySize = Self(key: .size, ascending: false)
    public static let byModified = Self(key: .modified, ascending: false)
    public static let byKind = Self(key: .kind)
    public static let byExtension = Self(key: .fileExtension)

    // MARK: - Comparison

    /// Returns `.orderedAscending`, `.orderedSame`, or `.orderedDescending`.
    public func compare(_ left: FileItem, _ right: FileItem) -> ComparisonResult {
        // 1. Directories-first check (never flipped by `ascending`).
        if self.directoriesFirst {
            let leftIsDir = left.kind == .directory
            let rightIsDir = right.kind == .directory
            if leftIsDir, !rightIsDir { return .orderedAscending }
            if !leftIsDir, rightIsDir { return .orderedDescending }
        }

        // 2. Primary key.
        let primaryResult = self.primaryCompare(left, right)

        // 3. Apply ascending/descending.
        let oriented: ComparisonResult = if primaryResult == .orderedSame {
            .orderedSame
        } else {
            self.ascending ? primaryResult : primaryResult.flipped
        }

        // 4. Stable tiebreaker: locale-aware name ascending.
        if oriented == .orderedSame {
            return FilePath.localizedDisplayNameCompare(left.path, right.path, locale: self.locale)
        }
        return oriented
    }

    /// Returns `true` when `left` should appear before `right`.
    public func callAsFunction(_ left: FileItem, _ right: FileItem) -> Bool {
        self.compare(left, right) == .orderedAscending
    }

    // MARK: - Private helpers

    private func primaryCompare(_ left: FileItem, _ right: FileItem) -> ComparisonResult {
        switch self.key {
        case .name:
            FilePath.localizedDisplayNameCompare(left.path, right.path, locale: self.locale)
        case .size:
            self.compare(left.attributes.sizeInBytes ?? -1, right.attributes.sizeInBytes ?? -1)
        case .modified:
            self.compare(
                left.attributes.modificationDate ?? .distantPast,
                right.attributes.modificationDate ?? .distantPast
            )
        case .kind:
            left.kind.rawValue.compare(right.kind.rawValue)
        case .fileExtension:
            self.fileExtension(of: left).compare(
                self.fileExtension(of: right),
                options: .caseInsensitive
            )
        }
    }

    private func compare(_ left: Int64, _ right: Int64) -> ComparisonResult {
        if left < right { return .orderedAscending }
        if left > right { return .orderedDescending }
        return .orderedSame
    }

    private func compare(_ left: Date, _ right: Date) -> ComparisonResult {
        left.compare(right)
    }

    private func fileExtension(of item: FileItem) -> String {
        let name = item.path.displayName
        guard let dotIndex = name.lastIndex(of: "."),
              dotIndex != name.startIndex else { return "" }
        return String(name[name.index(after: dotIndex)...])
    }
}

private extension ComparisonResult {
    var flipped: ComparisonResult {
        switch self {
        case .orderedAscending: .orderedDescending
        case .orderedDescending: .orderedAscending
        case .orderedSame: .orderedSame
        }
    }
}

public extension Sequence<FileItem> {
    func sorted(by descriptor: FileItemSortDescriptor) -> [FileItem] {
        self.sorted(by: descriptor.callAsFunction)
    }
}
