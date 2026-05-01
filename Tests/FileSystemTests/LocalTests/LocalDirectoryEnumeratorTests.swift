import Core
import FileSystemLocal
import Foundation
import XCTest

final class LocalDirectoryEnumeratorTests: XCTestCase {
    private var fixture = TempDirectoryFixture()

    override func setUp() async throws {
        self.fixture = TempDirectoryFixture()
        try self.fixture.setUp()
    }

    override func tearDown() async throws {
        self.fixture.tearDown()
    }

    func testEnumerateEmptyDirectory() async throws {
        let items = try await collect(fixture.path, options: .default)
        XCTAssertTrue(items.isEmpty)
    }

    func testEnumerateListsFiles() async throws {
        try self.fixture.makeFile(name: "a.txt")
        try self.fixture.makeFile(name: "b.txt")
        let items = try await collect(fixture.path, options: .default)
        XCTAssertEqual(items.count, 2)
        let names = Set(items.map { $0.path.lastComponent ?? "" })
        XCTAssertEqual(names, ["a.txt", "b.txt"])
    }

    func testHiddenFilesExcludedByDefault() async throws {
        try self.fixture.makeFile(name: "visible.txt")
        try self.fixture.makeFile(name: ".hidden")
        let options = EnumerationOptions(includesHiddenFiles: false, isRecursive: false, followsSymbolicLinks: false)
        let items = try await collect(fixture.path, options: options)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.path.lastComponent, "visible.txt")
    }

    func testHiddenFilesIncludedWhenRequested() async throws {
        try self.fixture.makeFile(name: "visible.txt")
        try self.fixture.makeFile(name: ".hidden")
        let options = EnumerationOptions(includesHiddenFiles: true, isRecursive: false, followsSymbolicLinks: false)
        let items = try await collect(fixture.path, options: options)
        XCTAssertEqual(items.count, 2)
    }

    func testNonRecursiveSkipsSubdirectories() async throws {
        try self.fixture.makeFile(name: "root.txt")
        let sub = try fixture.makeSubdirectory(name: "subdir")
        try "x".write(to: sub.appendingPathComponent("child.txt"), atomically: true, encoding: .utf8)

        let options = EnumerationOptions(includesHiddenFiles: false, isRecursive: false, followsSymbolicLinks: false)
        let items = try await collect(fixture.path, options: options)
        // Only root.txt + the directory entry itself; no child.txt
        XCTAssertFalse(items.contains { $0.path.lastComponent == "child.txt" })
    }

    func testRecursiveYieldsDescendants() async throws {
        try self.fixture.makeFile(name: "root.txt")
        let sub = try fixture.makeSubdirectory(name: "subdir")
        try "x".write(to: sub.appendingPathComponent("child.txt"), atomically: true, encoding: .utf8)

        let options = EnumerationOptions(includesHiddenFiles: false, isRecursive: true, followsSymbolicLinks: false)
        let items = try await collect(fixture.path, options: options)
        let names = items.map { $0.path.lastComponent ?? "" }
        XCTAssertTrue(names.contains("child.txt"))
    }

    func testCancellationMidStream() async throws {
        for i in 0 ..< 20 {
            _ = try self.fixture.makeFile(name: "file\(i).txt")
        }
        let provider = LocalFileSystemProvider()
        var count = 0
        for try await _ in provider.enumerate(at: self.fixture.path, options: .default) {
            count += 1
            if count == 3 { break }
        }
        XCTAssertEqual(count, 3)
    }

    func testNotFoundError() async throws {
        let missing = FilePath(scheme: .local, posix: fixture.url.path + "/does-not-exist")
        let provider = LocalFileSystemProvider()
        let stream = provider.enumerate(at: missing, options: .default)
        do {
            for try await _ in stream {}
            XCTFail("Expected error")
        } catch let error as StevedoreError {
            if case .fileSystem(.notFound) = error { } else {
                XCTFail("Expected .notFound, got \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func collect(_ path: FilePath, options: EnumerationOptions) async throws -> [FileItem] {
        let provider = LocalFileSystemProvider()
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: path, options: options) {
            items.append(item)
        }
        return items
    }
}
