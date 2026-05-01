import Core

/// Namespace sentinel for the FileSystemRemote module.
/// Downstream sessions that add named files to this module should preserve this
/// constant so `FileSystemRemoteSmokeTests` continues to pass.
public enum FileSystemRemoteModule {
    public static let moduleName = "FileSystemRemote"
}
