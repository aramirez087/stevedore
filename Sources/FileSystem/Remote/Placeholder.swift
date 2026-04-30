import Core

/// Marker namespace for the `FileSystemRemote` module. Replaced once the
/// SFTP/FTP/WebDAV/S3 providers land in Sessions 12–17.
public enum FileSystemRemoteModule {
    public static let moduleName: String = "FileSystemRemote"
}
