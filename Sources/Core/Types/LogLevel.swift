/// Severity levels used by `AppLogger`.
///
/// Ordered from least to most severe. Mapping to underlying log backends
/// (e.g., `swift-log`, `os.Logger`) happens inside the logging service.
public enum LogLevel: Int, Codable, Sendable, Hashable, CaseIterable, Comparable {
    case trace = 0
    case debug = 1
    case info = 2
    case notice = 3
    case warning = 4
    case error = 5
    case critical = 6

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Categories scope log entries to a subsystem so that filters and signposts
/// stay coherent across modules.
public enum LogCategory: String, Codable, Sendable, Hashable, CaseIterable {
    case app
    case fileSystem
    case remote
    case archive
    case credentials
    case settings
    case operations
    case sync
    case rename
    case preview
    case git
    case uninstaller
    case ui
    case unknown
}
