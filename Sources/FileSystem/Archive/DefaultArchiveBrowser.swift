import Core
import Foundation

/// Concrete implementation of `Core.ArchiveBrowser`.
///
/// Backed by `ArchiveDetector` for format discovery and the appropriate
/// `ArchiveBackend` for entry listing. Only `.local` scheme paths are
/// supported in the MVP.
public struct DefaultArchiveBrowser: ArchiveBrowser {
    public init() {}

    public func isArchive(_ path: FilePath) async -> Bool {
        guard path.scheme == .local else { return false }
        let url = URL(fileURLWithPath: path.posixString)
        return await ArchiveDetector.isArchive(url)
    }

    public func entries(in archive: FilePath) async throws -> [FileItem] {
        guard archive.scheme == .local else {
            throw StevedoreError.unsupported("ArchiveBrowser only supports local paths in MVP")
        }
        let url = URL(fileURLWithPath: archive.posixString)
        guard let format = await ArchiveDetector.detect(at: url) else {
            throw StevedoreError.archive(.unsupportedFormat)
        }
        let backend = try Self.makeBackend(format: format)
        let rawEntries = try await backend.listEntries(at: url)
        let mountComponents = archive.components
        return rawEntries
            .map { $0.asFileItem(mountComponents: mountComponents, scheme: .local) }
            .sorted { $0.path.posixString < $1.path.posixString }
    }

    // MARK: - Private

    private static func makeBackend(format: ArchiveFormat) throws -> any ArchiveBackend {
        switch format {
        case .zip:
            ZipBackend()
        case .tar, .tarGzip, .tarBzip2:
            try TarBackend(format: format)
        }
    }
}
