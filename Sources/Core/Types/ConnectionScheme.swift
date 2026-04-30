/// Identifies the transport / namespace used to address a `FilePath`.
///
/// Every concrete `FileSystemProvider` advertises a single scheme. Paths from
/// different schemes are never directly interchangeable; bridging happens at
/// the operation engine layer.
public enum ConnectionScheme: String, Codable, Sendable, Hashable, CaseIterable {
    case local
    case sftp
    case ftp
    case webdav
    case s3
    case smb
}
