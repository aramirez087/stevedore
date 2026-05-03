import Core

/// Sentinel namespace for the `FileSystemLocal` module.
/// Preserved so the out-of-touches smoke test at
/// `Tests/FileSystemTests/Local/FileSystemLocalSmokeTests.swift` continues to
/// pass after `Placeholder.swift` is removed.
public enum FileSystemLocalModule {
    public static let moduleName: String = "FileSystemLocal"
}
