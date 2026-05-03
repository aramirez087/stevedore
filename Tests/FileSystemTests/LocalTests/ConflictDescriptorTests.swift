import Core
import FileSystemLocal
import Foundation
import XCTest

final class ConflictDescriptorTests: XCTestCase {
    private var fixture = TempDirectoryFixture()

    override func setUp() async throws {
        self.fixture = TempDirectoryFixture()
        try self.fixture.setUp()
    }

    override func tearDown() async throws {
        self.fixture.tearDown()
    }

    func testNoConflictsWhenDestinationIsClear() async throws {
        let provider = LocalFileSystemProvider()
        let srcURL = try fixture.makeFile(name: "src.txt")
        let emptyDest = self.fixture.path.appending("empty_dest")
        _ = try self.fixture.makeSubdirectory(name: "empty_dest")
        let op = OperationDescriptor(
            kind: .copy,
            sources: [FilePath(scheme: .local, posix: srcURL.path)],
            destination: emptyDest
        )
        let conflicts = await provider.detectConflicts(for: op)
        XCTAssertTrue(conflicts.isEmpty)
    }

    func testDetectsExistingDestination() async throws {
        let provider = LocalFileSystemProvider()
        let srcURL = try fixture.makeFile(name: "file.txt", content: "src")
        let destDir = self.fixture.url.appendingPathComponent("dest", isDirectory: true)
        try FileManager().createDirectory(at: destDir, withIntermediateDirectories: true)
        try "old".write(to: destDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let destPath = FilePath(scheme: .local, posix: destDir.path)
        let op = OperationDescriptor(kind: .copy, sources: [srcPath], destination: destPath)
        let conflicts = await provider.detectConflicts(for: op)
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.reason, .destinationExists)
        XCTAssertEqual(conflicts.first?.operationKind, .copy)
    }

    func testDetectsDestinationIsDirectory() async throws {
        let provider = LocalFileSystemProvider()
        let srcURL = try fixture.makeFile(name: "file.txt")
        let destDir = self.fixture.url.appendingPathComponent("dest", isDirectory: true)
        try FileManager().createDirectory(at: destDir, withIntermediateDirectories: true)
        // Create a directory with the same name as the source file
        try FileManager().createDirectory(
            at: destDir.appendingPathComponent("file.txt"),
            withIntermediateDirectories: true
        )
        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let destPath = FilePath(scheme: .local, posix: destDir.path)
        let op = OperationDescriptor(kind: .copy, sources: [srcPath], destination: destPath)
        let conflicts = await provider.detectConflicts(for: op)
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.reason, .destinationIsDirectory)
    }

    func testMkdirHasNoConflictWhenTargetAbsent() async {
        let provider = LocalFileSystemProvider()
        let newDir = self.fixture.path.appending("brand_new")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: newDir)
        let conflicts = await provider.detectConflicts(for: op)
        XCTAssertTrue(conflicts.isEmpty)
    }
}
