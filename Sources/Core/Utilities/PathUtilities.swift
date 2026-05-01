import Foundation

public extension FilePath {
    /// Returns the relative components from `base` to `self`.
    ///
    /// - Returns `[]` when `self == base` (base IS self; zero hops).
    /// - Returns `nil` when schemes differ or `base` is not a prefix of `self`.
    func relative(to base: FilePath) -> [String]? {
        guard self.scheme == base.scheme else { return nil }
        guard self.components.starts(with: base.components) else { return nil }
        return Array(self.components.dropFirst(base.components.count))
    }

    /// Relative components joined with `/`, or `nil` when `base` is not a prefix.
    func relativePosix(to base: FilePath) -> String? {
        guard let parts = self.relative(to: base) else { return nil }
        return parts.joined(separator: "/")
    }

    /// Longest common ancestor for two paths of the same scheme.
    /// Returns `nil` only when the schemes differ; equal roots yield a root path.
    static func commonAncestor(_ left: FilePath, _ right: FilePath) -> FilePath? {
        guard left.scheme == right.scheme else { return nil }
        let shared = zip(left.components, right.components)
            .prefix(while: { $0.0 == $0.1 })
            .map(\.0)
        return FilePath(scheme: left.scheme, components: Array(shared))
    }

    /// Appends a raw POSIX fragment that may contain `/` separators and `..`.
    /// Normalization (in `init(scheme:posix:)`) handles `.` and `..` eagerly.
    func appending(posix fragment: String) -> FilePath {
        FilePath(scheme: self.scheme, posix: self.posixString + "/" + fragment)
    }

    /// Display name for UI rows: `lastComponent` for non-root paths,
    /// `scheme.rawValue + ":/"` for root paths so rows are never empty.
    var displayName: String {
        self.lastComponent ?? (self.scheme.rawValue + ":/")
    }

    /// Locale-sensitive comparison of `displayName`.
    /// Uses `[.caseInsensitive, .numeric, .diacriticInsensitive]` so
    /// "file10" sorts after "file2".
    static func localizedDisplayNameCompare(
        _ left: FilePath,
        _ right: FilePath,
        locale: Locale = .current
    ) -> ComparisonResult {
        left.displayName.compare(
            right.displayName,
            options: [.caseInsensitive, .numeric, .diacriticInsensitive],
            range: nil,
            locale: locale
        )
    }

    /// Parses a URL-style string into a `FilePath`.
    ///
    /// Supported schemes: `file` → `.local`, `sftp` → `.sftp`, `ftp` → `.ftp`,
    /// `webdav`/`http`/`https` → `.webdav`, `s3` → `.s3`, `smb` → `.smb`.
    /// Returns `nil` for unrecognised schemes or unparseable URLs.
    static func from(urlString: String) -> FilePath? {
        guard let url = URL(string: urlString),
              let rawScheme = url.scheme?.lowercased() else { return nil }
        let scheme: ConnectionScheme
        switch rawScheme {
        case "file": scheme = .local
        case "sftp": scheme = .sftp
        case "ftp": scheme = .ftp
        case "webdav", "http", "https": scheme = .webdav
        case "s3": scheme = .s3
        case "smb": scheme = .smb
        default: return nil
        }
        let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        return FilePath(scheme: scheme, components: components)
    }
}
