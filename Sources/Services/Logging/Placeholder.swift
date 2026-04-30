import Core

/// Marker namespace for the `ServicesLogging` module. Replaced once the
/// `swift-log` + `os.Logger` bridge lands in a downstream logging session.
public enum ServicesLoggingModule {
    public static let moduleName: String = "ServicesLogging"
}
