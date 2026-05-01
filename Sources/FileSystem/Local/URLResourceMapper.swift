import Core
import Foundation

// swiftlint:disable:next file_types_order
private let resourceKeys: Set<URLResourceKey> = [
    .nameKey,
    .isDirectoryKey,
    .isRegularFileKey,
    .isSymbolicLinkKey,
    .fileResourceTypeKey,
    .fileSizeKey,
    .totalFileSizeKey,
    .contentModificationDateKey,
    .creationDateKey,
    .fileSecurityKey,
    .isHiddenKey,
    .isPackageKey,
]

/// The set of `URLResourceKey`s read for every enumerated path.
let URLResourceMapperKeys: Set<URLResourceKey> = resourceKeys

/// Maps a `URL` + its prefetched `URLResourceValues` to Stevedore domain types.
enum URLResourceMapper {
    /// Translate a URL and its resource values into a `FileItem`.
    static func fileItem(url: URL, values: URLResourceValues) -> FileItem {
        let path = FilePath(scheme: .local, posix: url.path)
        let kind = self.fileKind(values: values)
        let attributes = self.fileAttributes(url: url, values: values, kind: kind)
        return FileItem(path: path, kind: kind, attributes: attributes)
    }

    /// Map `URLResourceValues` → `FileKind`.
    static func fileKind(values: URLResourceValues) -> FileKind {
        if values.isSymbolicLink == true { return .symbolicLink }
        if values.isDirectory == true { return .directory }
        if values.isRegularFile == true { return .regularFile }
        switch values.fileResourceType {
        case .some(.socket): return .socket
        case .some(.characterSpecial): return .characterDevice
        case .some(.blockSpecial): return .blockDevice
        case .some(.namedPipe): return .fifo
        default: return .unknown
        }
    }

    /// Map `URLResourceValues` → `FileAttributes`.
    static func fileAttributes(url: URL, values: URLResourceValues, kind: FileKind) -> FileAttributes {
        let size = values.fileSize.map { Int64($0) }
            ?? values.totalFileSize.map { Int64($0) }

        let permissions = self.posixPermissions(values: values)

        var symlinkTarget: String?
        if kind == .symbolicLink {
            symlinkTarget = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)
        }

        return FileAttributes(
            sizeInBytes: size,
            modificationDate: values.contentModificationDate,
            creationDate: values.creationDate,
            permissions: permissions,
            isHidden: values.isHidden ?? false,
            isPackage: values.isPackage ?? false,
            isSymbolicLink: kind == .symbolicLink,
            symbolicLinkTarget: symlinkTarget
        )
    }

    // MARK: - Private helpers

    private static func posixPermissions(values: URLResourceValues) -> PosixPermissions? {
        guard let security = values.fileSecurity else { return nil }
        var mode: mode_t = 0
        guard CFFileSecurityGetMode(security, &mode) else { return nil }
        return PosixPermissions(rawMode: UInt16(mode & 0o777))
    }
}
