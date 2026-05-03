import Core
import Foundation
import ServicesSettings
import XCTest

final class BookmarksRepositoryTests: XCTestCase {
    private var testDirectory: URL!
    private var store: JSONFileStore!
    private var repo: BookmarksRepository!

    override func setUp() async throws {
        try await super.setUp()
        self.testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookmarksRepoTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: self.testDirectory, withIntermediateDirectories: true)
        self.store = try JSONFileStore(directory: self.testDirectory, filename: "bookmarks")
        self.repo = BookmarksRepository(store: self.store)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.testDirectory)
        try await super.tearDown()
    }

    private func makeBookmark(name: String = "Test") -> Bookmark {
        Bookmark(displayName: name, path: FilePath(scheme: .local, posix: "/Users/test/\(name)"))
    }

    // MARK: - Tests

    func testAllReturnsEmptyWhenFileAbsent() async {
        let items = await self.repo.all()
        XCTAssertTrue(items.isEmpty)
    }

    func testSaveAndFetchRoundTrip() async throws {
        let bookmarks = [makeBookmark(name: "A"), makeBookmark(name: "B")]
        try await self.repo.save(bookmarks)
        let fetched = await self.repo.all()
        XCTAssertEqual(fetched, bookmarks)
    }

    func testObserveEmitsCurrentOnSubscribe() async {
        let stream = self.repo.observe()
        var iterator = stream.makeAsyncIterator()
        let initial = await iterator.next()
        XCTAssertEqual(initial, [])
    }

    func testObserveEmitsAfterSave() async throws {
        let stream = self.repo.observe()
        var iterator = stream.makeAsyncIterator()

        let initial = await iterator.next()
        XCTAssertEqual(initial, [])

        try await self.repo.save([self.makeBookmark()])

        let updated = await iterator.next()
        XCTAssertEqual(updated?.count, 1)
    }

    func testObserveCancelsCleanly() async {
        let stream = self.repo.observe()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()
        // iterator goes out of scope → onTermination fires → no crash
    }
}
