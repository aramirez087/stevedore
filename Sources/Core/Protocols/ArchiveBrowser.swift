/// Reads entries from a supported archive file (.zip, .tar, .tar.gz, .tar.bz2).
public protocol ArchiveBrowser: Sendable {
    /// True when `path` is recognized as an archive this browser can open.
    func isArchive(_ path: FilePath) async -> Bool

    /// Logical entries inside the archive, expressed as virtual `FileItem`
    /// values rooted at the archive path.
    func entries(in archive: FilePath) async throws -> [FileItem]
}
