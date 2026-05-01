import Core
import Foundation

/// Normalized metadata for a single entry inside an archive.
///
/// All path components are validated: never empty, never `.` or `..`, never
/// starting with `/`. Backends must validate before constructing an entry.
struct ArchiveEntry: Hashable, Sendable {
    let pathComponents: [String]
    let kind: FileKind
    let sizeInBytes: Int64?
    let modificationDate: Date?
    let permissions: PosixPermissions?
    let symbolicLinkTarget: String?

    /// Relative POSIX path (no leading slash).
    var relativePath: String {
        self.pathComponents.joined(separator: "/")
    }

    /// Convert to a `FileItem` whose `FilePath` is rooted inside the archive's
    /// virtual mount. `mountComponents` are the path components of the archive
    /// file itself within the provider's coordinate space.
    func asFileItem(mountComponents: [String], scheme: ConnectionScheme) -> FileItem {
        let fullComponents = mountComponents + self.pathComponents
        let path = FilePath(scheme: scheme, components: fullComponents)
        let attrs = FileAttributes(
            sizeInBytes: self.sizeInBytes,
            modificationDate: self.modificationDate,
            permissions: self.permissions,
            isHidden: self.pathComponents.last?.hasPrefix(".") ?? false,
            isSymbolicLink: self.kind == .symbolicLink,
            symbolicLinkTarget: self.symbolicLinkTarget
        )
        return FileItem(path: path, kind: self.kind, attributes: attrs)
    }
}

/// Validates a raw archive entry path and splits it into components.
///
/// Throws `StevedoreError.archive(.corruptedEntry(detail:))` on traversal
/// attempts or malformed paths.
func validateAndSplitEntryPath(_ rawPath: String) throws -> [String] {
    guard !rawPath.hasPrefix("/") else {
        throw StevedoreError.archive(.corruptedEntry(detail: "path traversal attempt: \(rawPath)"))
    }
    guard !rawPath.hasPrefix("~") else {
        throw StevedoreError.archive(.corruptedEntry(detail: "path traversal attempt: \(rawPath)"))
    }
    guard !rawPath.contains("\0") else {
        throw StevedoreError.archive(.corruptedEntry(detail: "NUL byte in path: \(rawPath)"))
    }
    let components = rawPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    for component in components where component == ".." {
        throw StevedoreError.archive(.corruptedEntry(detail: "path traversal attempt: \(rawPath)"))
    }
    guard !components.isEmpty else {
        throw StevedoreError.archive(.corruptedEntry(detail: "empty path in archive entry"))
    }
    return components
}
