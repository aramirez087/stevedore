/// Composable predicate wrapper for `FileItem` collections.
public struct FileItemFilter: Sendable {
    public typealias Predicate = @Sendable (FileItem) -> Bool

    public let predicate: Predicate

    public init(_ predicate: @escaping Predicate) {
        self.predicate = predicate
    }

    // MARK: - Combinators

    public func and(_ other: Self) -> Self {
        Self { item in self.predicate(item) && other.predicate(item) }
    }

    public func or(_ other: Self) -> Self {
        Self { item in self.predicate(item) || other.predicate(item) }
    }

    public func negated() -> Self {
        Self { item in !self.predicate(item) }
    }

    public func callAsFunction(_ item: FileItem) -> Bool {
        self.predicate(item)
    }

    // MARK: - Built-ins

    public static let any = Self { _ in true }
    public static let none = Self { _ in false }
    public static let visible = Self { item in !item.attributes.isHidden }
    public static let hiddenOnly = Self { item in item.attributes.isHidden }

    public static func kind(_ fileKind: FileKind) -> Self {
        Self { item in item.kind == fileKind }
    }

    public static func kinds(_ fileKinds: Set<FileKind>) -> Self {
        Self { item in fileKinds.contains(item.kind) }
    }

    /// Glob filter matched against the item's `posixString`.
    /// Patterns without `/` are prefixed with `**/` for ergonomic matching.
    public static func glob(_ pattern: String, caseSensitive: Bool = true) -> Self {
        Self { item in
            GlobMatcher.matches(
                pattern: pattern,
                path: item.path.posixString,
                caseSensitive: caseSensitive
            )
        }
    }
}

// MARK: - GlobMatcher

/// Standalone glob-matching engine. Supports `*`, `?`, and `**`.
///
/// - `?` matches exactly one character within a single path segment.
/// - `*` matches zero or more characters within a single segment (does not cross `/`).
/// - `**` matches zero or more complete path components.
/// - Patterns without `/` are internally prefixed with `**/`.
/// - Bracket sets (`[abc]`) and brace expansion are not supported.
public enum GlobMatcher {
    public static func matches(
        pattern: String,
        path: String,
        caseSensitive: Bool = true
    ) -> Bool {
        let resolvedPattern = pattern.contains("/") ? pattern : "**/" + pattern
        let patternSegs = resolvedPattern
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        let pathSegs = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        return self.matchComponents(
            pattern: patternSegs,
            pi: 0,
            path: pathSegs,
            si: 0,
            caseSensitive: caseSensitive
        )
    }

    // MARK: - Component-level matcher (outer loop)

    private static func matchComponents(
        pattern: [String],
        pi: Int,
        path: [String],
        si: Int,
        caseSensitive: Bool
    ) -> Bool {
        var pi = pi
        var si = si

        while pi < pattern.count {
            let seg = pattern[pi]

            if seg == "**" {
                // Normalize consecutive `**` into one.
                var nextPi = pi + 1
                while nextPi < pattern.count, pattern[nextPi] == "**" {
                    nextPi += 1
                }
                // `**` at the end matches everything remaining.
                if nextPi == pattern.count { return true }
                // Try matching the rest of the pattern at every remaining path position.
                return (si ... path.count).contains { trySi in
                    self.matchComponents(
                        pattern: pattern,
                        pi: nextPi,
                        path: path,
                        si: trySi,
                        caseSensitive: caseSensitive
                    )
                }
            }

            guard si < path.count else { return false }
            guard self.matchSegment(seg, against: path[si], caseSensitive: caseSensitive) else {
                return false
            }
            pi += 1
            si += 1
        }

        return si == path.count
    }

    // MARK: - Single-segment matcher (inner loop)

    private static func matchSegment(
        _ pattern: String,
        against text: String,
        caseSensitive: Bool
    ) -> Bool {
        let p = caseSensitive ? pattern : pattern.lowercased()
        let t = caseSensitive ? text : text.lowercased()
        return self.matchSegmentChars(
            pattern: Array(p),
            pi: 0,
            text: Array(t),
            ti: 0
        )
    }

    private static func matchSegmentChars(
        pattern: [Character],
        pi: Int,
        text: [Character],
        ti: Int
    ) -> Bool {
        var pi = pi
        var ti = ti
        var starPi = -1
        var starTi = -1

        while ti < text.count {
            if pi < pattern.count, pattern[pi] == "*" {
                starPi = pi
                starTi = ti
                pi += 1
            } else if pi < pattern.count, pattern[pi] == "?" || pattern[pi] == text[ti] {
                pi += 1
                ti += 1
            } else if starPi >= 0 {
                // Backtrack: advance the saved text position.
                starTi += 1
                ti = starTi
                pi = starPi + 1
            } else {
                return false
            }
        }

        // Consume trailing `*` wildcards.
        while pi < pattern.count, pattern[pi] == "*" {
            pi += 1
        }

        return pi == pattern.count
    }
}
