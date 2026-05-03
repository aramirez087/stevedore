import Core
import XCTest

/// Shared conformance tests exercised by every remote provider test suite.
///
/// Subtypes supply a provider backed by fakes, call `runAll()` from `setUp`,
/// and get basic `FileSystemProvider` contract coverage for free.
protocol FileSystemProviderConformanceSuite {
    /// Return a fresh provider with a known initial state.
    ///
    /// The provider must expose at least one child item at the root path and
    /// support creating a directory, renaming, and deleting items.
    func makeProvider() async throws -> any FileSystemProvider
    /// The scheme the provider reports.
    var expectedScheme: ConnectionScheme { get }
    /// Root path appropriate for this provider.
    var rootPath: FilePath { get }
    /// A path that is known to exist in the provider's initial state.
    var existingFilePath: FilePath { get }
}

extension FileSystemProviderConformanceSuite where Self: XCTestCase {
    func runConformanceTests() async throws {
        try await self.testSchemeMatchesExpected()
        try await self.testWatchReturnsEmptyStream()
        try await self.testEnumerateRootYieldsItems()
        try await self.testAttributesOnExistingPath()
    }

    func testSchemeMatchesExpected() async throws {
        let provider = try await makeProvider()
        XCTAssertEqual(provider.scheme, expectedScheme)
    }

    func testWatchReturnsEmptyStream() async throws {
        let provider = try await makeProvider()
        let stream = provider.watch(rootPath)
        var count = 0
        for await _ in stream {
            count += 1
        }
        XCTAssertEqual(count, 0)
    }

    func testEnumerateRootYieldsItems() async throws {
        let provider = try await makeProvider()
        var items: [FileItem] = []
        let stream = provider.enumerate(at: rootPath, options: EnumerationOptions())
        for try await item in stream {
            items.append(item)
        }
        XCTAssertFalse(items.isEmpty, "enumerate(root) must yield at least one item")
    }

    func testAttributesOnExistingPath() async throws {
        let provider = try await makeProvider()
        let attrs = try await provider.attributes(at: existingFilePath)
        XCTAssertNotNil(attrs)
    }
}
