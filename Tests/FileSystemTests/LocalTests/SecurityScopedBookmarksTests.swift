import Core
import FileSystemLocal
import Foundation
import XCTest

final class SecurityScopedBookmarksTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() async throws {
        self.tempURL = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager().createDirectory(at: self.tempURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager().removeItem(at: self.tempURL)
    }

    func testEncodeDecodeRoundTrip() throws {
        let data = try SecurityScopedBookmarks.encode(self.tempURL)
        XCTAssertFalse(data.isEmpty)
        let decoded = try SecurityScopedBookmarks.decode(data)
        // The resolved path should point to the same location (accounting for symlinks).
        XCTAssertEqual(
            decoded.url.resolvingSymlinksInPath().path,
            self.tempURL.resolvingSymlinksInPath().path
        )
        XCTAssertFalse(decoded.isStale)
    }

    func testWithAccessBalancesStartStop() async throws {
        // withAccess should not throw for a plain URL (even without sandbox entitlement).
        // Return a value from the body to verify it was called.
        let result = try await SecurityScopedBookmarks.withAccess(to: self.tempURL) { url in
            url.path
        }
        XCTAssertEqual(result, self.tempURL.path)
    }

    func testWithAccessPropagatesBodyError() async throws {
        struct Sentinel: Error {}
        do {
            try await SecurityScopedBookmarks.withAccess(to: self.tempURL) { _ in
                throw Sentinel()
            }
            XCTFail("Should have thrown")
        } catch is Sentinel {
            // expected
        }
    }
}
