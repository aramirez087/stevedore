import Core
import Foundation
import ZIPFoundation

/// Compression level for zip archive creation.
///
/// ZIPFoundation 0.9.x exposes only on/off DEFLATE; `.default` and `.best`
/// both map to `.deflate`. `.none` maps to `CompressionMethod.none`.
public enum CompressionLevel: Sendable {
    case none
    case `default`
    case best
}

/// Builds ZIP archives from a list of source URLs.
///
/// Tar creation is out of scope for the MVP; only zip is supported.
public struct ArchiveCreator: Sendable {
    private let compressionLevel: CompressionLevel

    public init(compressionLevel: CompressionLevel = .default) {
        self.compressionLevel = compressionLevel
    }

    /// Create a zip archive containing `sources` with paths relative to `base`.
    ///
    /// - Parameters:
    ///   - sources: Source file/directory URLs to include.
    ///   - base: Common ancestor; entry paths inside the archive are relative to this URL.
    ///   - archive: Destination URL for the resulting zip file.
    ///   - progress: Optional progress reporter.
    /// - Returns: Size in bytes of the resulting archive file.
    @discardableResult
    public func createZip(
        sources: [URL],
        relativeTo base: URL,
        archive: URL,
        progress: (any OperationProgressReporting)? = nil
    ) async throws -> Int64 {
        let method = self.compressionMethod
        // Resolve symlinks once so all path comparisons use the canonical prefix.
        // On macOS /var is a symlink to /private/var, causing hasPrefix to fail otherwise.
        let canonicalBase = base.resolvingSymlinksInPath()
        return try await Task.detached(priority: .userInitiated) {
            let zip = try Archive(url: archive, accessMode: .create)

            for source in sources {
                let canonicalSource = source.resolvingSymlinksInPath()
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: canonicalSource.path, isDirectory: &isDirectory) else {
                    continue
                }
                if isDirectory.boolValue {
                    try Self.addDirectory(canonicalSource, canonicalBase: canonicalBase, to: zip, method: method)
                } else {
                    let relativePath = Self.relativePath(of: canonicalSource, to: canonicalBase)
                    try zip.addEntry(
                        with: relativePath,
                        fileURL: canonicalSource,
                        compressionMethod: method
                    )
                }
            }

            let attrs = try FileManager.default.attributesOfItem(atPath: archive.path)
            return (attrs[.size] as? NSNumber)?.int64Value ?? 0
        }.value
    }

    // MARK: - Private

    private var compressionMethod: CompressionMethod {
        switch self.compressionLevel {
        case .none: .none
        case .default, .best: .deflate
        }
    }

    private static func relativePath(of url: URL, to base: URL) -> String {
        let basePath = base.path.hasSuffix("/") ? base.path : base.path + "/"
        if url.path.hasPrefix(basePath) {
            return String(url.path.dropFirst(basePath.count))
        }
        return url.lastPathComponent
    }

    private static func addDirectory(
        _ directory: URL,
        canonicalBase: URL,
        to zip: Archive,
        method: CompressionMethod
    ) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        // Add directory entry first.
        let dirRelativePath = Self.relativePath(of: directory, to: canonicalBase) + "/"
        try zip.addEntry(
            with: dirRelativePath,
            type: .directory,
            uncompressedSize: 0,
            provider: { (_: Int64, _: Int) throws -> Data in Data() }
        )

        for case let fileURL as URL in enumerator {
            // FileManager.enumerator already returns resolved paths, use them directly.
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = resourceValues?.isDirectory ?? false
            let relativePath = Self.relativePath(of: fileURL, to: canonicalBase)

            if isDir {
                try zip.addEntry(
                    with: relativePath + "/",
                    type: .directory,
                    uncompressedSize: 0,
                    provider: { (_: Int64, _: Int) throws -> Data in Data() }
                )
            } else {
                try zip.addEntry(with: relativePath, fileURL: fileURL, compressionMethod: method)
            }
        }
    }
}
