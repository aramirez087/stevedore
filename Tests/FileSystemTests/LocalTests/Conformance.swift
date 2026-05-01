import Core
import FileSystemLocal
import Foundation
import XCTest

/// Provider conformance test suite.
///
/// Drives the canonical scenarios any `FileSystemProvider` must satisfy.
/// Subclasses override `makeProvider()` to exercise a different provider
/// (remote / archive sessions can adopt this base later).
class ProviderConformanceTests: XCTestCase {
    var fixture = TempDirectoryFixture()

    func makeProvider() -> any FileSystemProvider {
        LocalFileSystemProvider()
    }

    override func setUp() async throws {
        self.fixture = TempDirectoryFixture()
        try self.fixture.setUp()
    }

    override func tearDown() async throws {
        self.fixture.tearDown()
    }

    // MARK: - 1. Scheme

    func testProviderAdvertisesScheme() {
        let p = self.makeProvider()
        XCTAssertEqual(p.scheme, .local)
    }

    // MARK: - 2. Enumeration

    func testEnumerateEmptyDirectoryYieldsNothing() async throws {
        let p = self.makeProvider()
        var count = 0
        for try await _ in p.enumerate(at: self.fixture.path, options: .default) {
            count += 1
        }
        XCTAssertEqual(count, 0)
    }

    func testEnumerateRespectsHiddenFileFilter() async throws {
        _ = try self.fixture.makeFile(name: "visible.txt")
        _ = try self.fixture.makeFile(name: ".hidden")
        let p = self.makeProvider()
        let noHidden = EnumerationOptions(includesHiddenFiles: false, isRecursive: false, followsSymbolicLinks: false)
        var names: [String] = []
        for try await item in p.enumerate(at: self.fixture.path, options: noHidden) {
            names.append(item.path.lastComponent ?? "")
        }
        XCTAssertFalse(names.contains(".hidden"))
        XCTAssertTrue(names.contains("visible.txt"))
    }

    func testEnumerateRecursiveYieldsAllDescendants() async throws {
        _ = try self.fixture.makeFile(name: "top.txt")
        let sub = try fixture.makeSubdirectory(name: "sub")
        try "x".write(to: sub.appendingPathComponent("child.txt"), atomically: true, encoding: .utf8)

        let p = self.makeProvider()
        let recursive = EnumerationOptions(includesHiddenFiles: false, isRecursive: true, followsSymbolicLinks: false)
        var names: [String] = []
        for try await item in p.enumerate(at: self.fixture.path, options: recursive) {
            names.append(item.path.lastComponent ?? "")
        }
        XCTAssertTrue(names.contains("top.txt"))
        XCTAssertTrue(names.contains("child.txt"))
    }

    // MARK: - 3. Attributes

    func testAttributesForRegularFile() async throws {
        let fileURL = try fixture.makeFile(name: "measured.txt", content: "12345")
        let filePath = FilePath(scheme: .local, posix: fileURL.path)
        let p = self.makeProvider()
        let attrs = try await p.attributes(at: filePath)
        XCTAssertEqual(attrs.sizeInBytes, 5)
        XCTAssertNotNil(attrs.modificationDate)
    }

    func testAttributesForMissingPathThrowsNotFound() async throws {
        let missing = FilePath(scheme: .local, posix: fixture.url.appendingPathComponent("phantom").path)
        let p = self.makeProvider()
        do {
            _ = try await p.attributes(at: missing)
            XCTFail("Expected .notFound")
        } catch let e as StevedoreError {
            guard case .fileSystem(.notFound) = e else {
                XCTFail("Expected .fileSystem(.notFound), got \(e)")
                return
            }
        }
    }

    // MARK: - 4. Operations

    func testExecuteMkdirCreatesDirectory() async throws {
        let p = self.makeProvider()
        let newDir = self.fixture.path.appending("conform_mkdir")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: newDir)
        let result = try await p.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager().fileExists(atPath: newDir.posixString, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testExecuteCopyDuplicatesContents() async throws {
        let p = self.makeProvider()
        let srcURL = try fixture.makeFile(name: "src_conform.txt", content: "conform")
        let destDir = try fixture.makeSubdirectory(name: "conform_dest")
        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let destPath = FilePath(scheme: .local, posix: destDir.path)
        let op = OperationDescriptor(kind: .copy, sources: [srcPath], destination: destPath)
        let result = try await p.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        let destFile = destDir.appendingPathComponent("src_conform.txt")
        XCTAssertTrue(FileManager().fileExists(atPath: destFile.path))
        XCTAssertEqual(try String(contentsOf: destFile, encoding: .utf8), "conform")
    }

    func testExecuteMoveRemovesSource() async throws {
        let p = self.makeProvider()
        let srcURL = try fixture.makeFile(name: "move_src.txt", content: "move")
        let destDir = try fixture.makeSubdirectory(name: "move_dest")
        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let destPath = FilePath(scheme: .local, posix: destDir.path)
        let op = OperationDescriptor(kind: .move, sources: [srcPath], destination: destPath)
        let result = try await p.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertFalse(FileManager().fileExists(atPath: srcURL.path))
        XCTAssertTrue(FileManager().fileExists(atPath: destDir.appendingPathComponent("move_src.txt").path))
    }

    func testExecuteDeleteIsIdempotent() async throws {
        let p = self.makeProvider()
        let fileURL = try fixture.makeFile(name: "del_conform.txt")
        let filePath = FilePath(scheme: .local, posix: fileURL.path)
        let op = OperationDescriptor(kind: .delete, sources: [filePath])
        _ = try await p.execute(op, progress: nil)
        // Second delete — file is gone; should complete without error.
        let result2 = try await p.execute(op, progress: nil)
        XCTAssertEqual(result2.status, .completed)
        XCTAssertEqual(result2.itemsProcessed, 0)
    }

    func testExecuteRenameUpdatesPath() async throws {
        let p = self.makeProvider()
        let srcURL = try fixture.makeFile(name: "rename_src.txt")
        let destPath = FilePath(scheme: .local, posix: fixture.url.appendingPathComponent("rename_dest.txt").path)
        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let op = OperationDescriptor(kind: .rename, sources: [srcPath], destination: destPath)
        let result = try await p.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertFalse(FileManager().fileExists(atPath: srcURL.path))
        XCTAssertTrue(FileManager().fileExists(atPath: destPath.posixString))
    }

    // MARK: - 5. Watch

    func testWatchEmitsCreationEvent() async throws {
        let p = self.makeProvider()
        let stream = p.watch(self.fixture.path)

        try await Task.sleep(for: .milliseconds(200))
        _ = try self.fixture.makeFile(name: "watched_conform.txt")

        let task = Task<FilePathChange?, Never> {
            for await change in stream {
                return change
            }
            return nil
        }
        let timeoutTask = Task<Void, Never> {
            try? await Task.sleep(for: .seconds(5))
            task.cancel()
        }
        let change = await task.value
        timeoutTask.cancel()
        XCTAssertNotNil(change)
    }

    func testWatchTerminatesOnCancellation() async {
        let p = self.makeProvider()
        let stream = p.watch(self.fixture.path)
        for await _ in stream {
            break
        }
        // Reaching here without hang = pass
    }

    // MARK: - 6. Cancellation

    func testCancellationDuringEnumerationStopsCleanly() async throws {
        for i in 0 ..< 30 {
            _ = try self.fixture.makeFile(name: "cancel\(i).txt")
        }
        let p = self.makeProvider()
        var count = 0
        for try await _ in p.enumerate(at: self.fixture.path, options: .default) {
            count += 1
            if count == 5 { break }
        }
        XCTAssertEqual(count, 5)
    }
}

/// Concrete local subclass — satisfies the exit-criterion conformance suite.
final class LocalProviderConformanceTests: ProviderConformanceTests {
    override func makeProvider() -> any FileSystemProvider {
        LocalFileSystemProvider()
    }
}
