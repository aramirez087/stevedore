import Core
import Foundation

// MARK: - SearchPathKind

/// Ownership category for a search-path root.
public enum SearchPathKind: Sendable, Hashable {
    /// Resides under `~/Library/…` — the current user owns it and it can be
    /// moved to Trash without admin privileges.
    case user
    /// Resides under `/Library/…` — system/admin-owned; presented in results
    /// but never modified without explicit escalation.
    case system
}

// MARK: - SearchPath

/// A single root directory that `AssociatedFilesScanner` walks.
public struct SearchPath: Sendable, Hashable {
    public let url: URL
    public let kind: SearchPathKind

    public init(url: URL, kind: SearchPathKind) {
        self.url = url
        self.kind = kind
    }
}

// MARK: - SearchPaths

/// The canonical list of macOS locations that may contain per-app support files.
///
/// The list mirrors Apple's documented sandbox container layout and common
/// non-sandboxed conventions.  System paths are included for discovery only;
/// `UninstallExecutor` refuses to move anything under `/Library/…` to Trash.
public enum SearchPaths {
    // MARK: Public API

    /// All search paths used by the scanner.
    public static let all: [SearchPath] = userPaths + systemPaths

    // MARK: User paths (~Library)

    private static let userPaths: [SearchPath] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")
        let names = [
            "Application Support",
            "Caches",
            "Containers",
            "Group Containers",
            "Preferences",
            "Saved Application State",
            "LaunchAgents",
            "Logs",
            "HTTPStorages",
            "WebKit",
        ]
        return names.map { SearchPath(url: lib.appendingPathComponent($0), kind: .user) }
    }()

    // MARK: System paths (/Library)

    private static let systemPaths: [SearchPath] = {
        let lib = URL(filePath: "/Library")
        let names = [
            "Application Support",
            "Caches",
            "Preferences",
            "LaunchAgents",
            "LaunchDaemons",
            "Logs",
        ]
        return names.map { SearchPath(url: lib.appendingPathComponent($0), kind: .system) }
    }()
}
