import Core
import Foundation

/// Helpers for encoding, decoding, and accessing security-scoped bookmarks.
///
/// Full security-scoped bookmark resolution only works inside a sandboxed app
/// with the `com.apple.security.files.bookmarks.app-scope` entitlement.
/// These helpers compile and are unit-testable outside the sandbox; the
/// access-start/stop balance is always maintained regardless of entitlement.
public enum SecurityScopedBookmarks {
    public struct DecodedBookmark: Sendable {
        public let url: URL
        public let isStale: Bool
    }

    /// Encode `url` as bookmark data. Includes security-scope flags when
    /// the app sandbox entitlement is present.
    public static func encode(_ url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            // Fall back to a plain (non-security-scoped) bookmark so the API
            // stays functional outside the sandbox during unit tests.
            return try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    /// Decode bookmark `data` back to a `URL`.
    public static func decode(_ data: Data) throws -> DecodedBookmark {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }
        return DecodedBookmark(url: url, isStale: isStale)
    }

    /// Start accessing a security-scoped resource, run `body`, then stop.
    /// Balances start/stop even when `body` throws or returns early.
    public static func withAccess<T: Sendable>(
        to url: URL,
        _ body: @Sendable (URL) async throws -> T
    ) async throws -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        return try await body(url)
    }
}
