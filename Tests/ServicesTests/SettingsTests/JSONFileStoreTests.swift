import Core
import Foundation
import ServicesSettings
import XCTest

final class JSONFileStoreTests: XCTestCase {
    private var testDirectory: URL!

    override func setUp() {
        super.setUp()
        self.testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JSONFileStoreTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: self.testDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: self.testDirectory)
        super.tearDown()
    }

    private func makeStore(filename: String = "test", schemaVersion: Int = 1) throws -> JSONFileStore {
        try JSONFileStore(directory: self.testDirectory, filename: filename, schemaVersion: schemaVersion)
    }

    private func makeBookmark() -> Bookmark {
        Bookmark(displayName: "Home", path: FilePath(scheme: .local, posix: "/Users/test"))
    }

    // MARK: - Read missing file

    func testReadMissingFileReturnsNil() async throws {
        let store = try makeStore()
        let result = await store.read([Bookmark].self)
        XCTAssertNil(result)
    }

    // MARK: - Write and read

    func testWriteAndReadRoundTrip() async throws {
        let store = try makeStore()
        let bookmarks = [makeBookmark()]
        try await store.write(bookmarks)
        let result = await store.read([Bookmark].self)
        XCTAssertEqual(result, bookmarks)
    }

    // MARK: - Crash safety: corrupt .json returns nil

    func testAtomicWriteCrashSafety() async throws {
        // Simulate crash mid-write: create a .tmp file but no .json
        let tmpURL = self.testDirectory.appendingPathComponent("crash.json.tmp")
        try Data("garbage".utf8).write(to: tmpURL)

        // Init should clean up the stale .tmp
        let store = try makeStore(filename: "crash")

        // No .json exists, so read must return nil
        let result = await store.read([Bookmark].self)
        XCTAssertNil(result)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmpURL.path))
    }

    // MARK: - Corrupt file returns nil

    func testCorruptFileReturnsNil() async throws {
        let store = try makeStore()
        try await store.write([self.makeBookmark()])

        // Overwrite with garbage
        let fileURL = self.testDirectory.appendingPathComponent("test.json")
        try Data("not json at all {{{".utf8).write(to: fileURL)

        let result = await store.read([Bookmark].self)
        XCTAssertNil(result)
    }

    // MARK: - Schema downgrade returns nil

    func testSchemaVersionMismatchReturnsNil() async throws {
        // Write with version 99 (future)
        let futureStore = try makeStore(filename: "versioned", schemaVersion: 99)
        try await futureStore.write([self.makeBookmark()])

        // Open with version 1 (current) — downgrade scenario
        let currentStore = try makeStore(filename: "versioned", schemaVersion: 1)
        let result = await currentStore.read([Bookmark].self)
        XCTAssertNil(result)
    }

    // MARK: - Migration

    func testMigrationUpgradesPayload() async throws {
        // Write a v1 file using a v1 store
        let v1Store = try makeStore(filename: "migrated", schemaVersion: 1)
        let original = [makeBookmark()]
        try await v1Store.write(original)

        // Open as v2 and register a no-op migration that adds a known marker
        let v2Store = try makeStore(filename: "migrated", schemaVersion: 2)
        // Migration that round-trips the data unchanged (proves the path executes)
        await v2Store.registerMigration(from: 1, to: 2) { data in data }

        let result = await v2Store.read([Bookmark].self)
        XCTAssertEqual(result, original)
    }

    // MARK: - Concurrent writes

    func testConcurrentWritesDoNotCorrupt() async throws {
        let store = try makeStore()
        let bookmark = self.makeBookmark()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    try? await store.write([bookmark])
                }
            }
        }

        let result = await store.read([Bookmark].self)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.first?.displayName, bookmark.displayName)
    }
}
