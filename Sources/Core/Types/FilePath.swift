/// A normalized, scheme-aware path.
///
/// `FilePath` is intentionally distinct from `Foundation.FilePath`: it carries
/// the originating `ConnectionScheme` so cross-scheme operations cannot be
/// expressed by accident. Components are POSIX-style, never empty, never `.`,
/// and `..` is collapsed eagerly.
public struct FilePath: Hashable, Sendable, Codable {
    public let scheme: ConnectionScheme
    public let components: [String]

    public init(scheme: ConnectionScheme, components: [String]) {
        self.scheme = scheme
        self.components = Self.normalize(components)
    }

    /// Convenience initializer accepting a POSIX-style string. A leading `/`
    /// is treated as the absolute root; any other prefix is interpreted
    /// relative to root.
    public init(scheme: ConnectionScheme, posix: String) {
        let raw = posix.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        self.init(scheme: scheme, components: raw)
    }

    /// Root path for a given scheme (no components).
    public static func root(_ scheme: ConnectionScheme) -> Self {
        Self(scheme: scheme, components: [])
    }

    /// True when this path has no components.
    public var isRoot: Bool {
        self.components.isEmpty
    }

    /// The final component (file or directory name), if any.
    public var lastComponent: String? {
        self.components.last
    }

    /// The parent path, or `nil` for the root.
    public var parent: Self? {
        guard !self.components.isEmpty else { return nil }
        return Self(scheme: self.scheme, components: Array(self.components.dropLast()))
    }

    /// Append a single component.
    public func appending(_ component: String) -> Self {
        Self(scheme: self.scheme, components: self.components + [component])
    }

    /// Append multiple components.
    public func appending(_ components: [String]) -> Self {
        Self(scheme: self.scheme, components: self.components + components)
    }

    /// POSIX-style string representation (`/a/b/c`). Always rooted.
    public var posixString: String {
        "/" + self.components.joined(separator: "/")
    }

    private static func normalize(_ raw: [String]) -> [String] {
        var stack: [String] = []
        for component in raw {
            if component.isEmpty || component == "." { continue }
            if component == ".." {
                if !stack.isEmpty { stack.removeLast() }
                continue
            }
            stack.append(component)
        }
        return stack
    }
}
