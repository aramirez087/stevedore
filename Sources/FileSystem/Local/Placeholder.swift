import Core

/// Marker namespace for the `FileSystemLocal` module. Replaced once the
/// concrete local-disk provider lands in Session 02. Smoke tests assert this
/// sentinel is reachable so the module is link-clean from downstream targets.
public enum FileSystemLocalModule {
    public static let moduleName: String = "FileSystemLocal"
}
