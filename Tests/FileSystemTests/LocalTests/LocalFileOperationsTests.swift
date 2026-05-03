import Core
import FileSystemLocal
import Foundation
import XCTest

final class LocalFileOperationsTests: XCTestCase {
    private var fixture = TempDirectoryFixture()

    override func setUp() async throws {
        self.fixture = TempDirectoryFixture()
        try self.fixture.setUp()
    }

    override func tearDown() async throws {
        self.fixture.tearDown()
    }

    // MARK: - mkdir

    func testMkdirCreatesDirectory() async throws {
        let provider = LocalFileSystemProvider()
        let newDir = self.fixture.path.appending("new_dir")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: newDir)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager().fileExists(atPath: newDir.posixString, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testMkdirSkipsOnConflictAsk() async throws {
        let provider = LocalFileSystemProvider()
        let existing = self.fixture.path.appending("existing")
        _ = try self.fixture.makeSubdirectory(name: "existing")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: existing, conflictPolicy: .ask)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .skipped)
    }

    // MARK: - copy

    func testCopyDuplicatesFile() async throws {
        let provider = LocalFileSystemProvider()
        let srcURL = try fixture.makeFile(name: "original.txt", content: "hello")
        let destDir = self.fixture.path.appending("dest")
        _ = try self.fixture.makeSubdirectory(name: "dest")

        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let op = OperationDescriptor(kind: .copy, sources: [srcPath], destination: destDir)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        let destURL = self.fixture.url.appendingPathComponent("dest/original.txt")
        XCTAssertTrue(FileManager().fileExists(atPath: destURL.path))
        let content = try String(contentsOf: destURL, encoding: .utf8)
        XCTAssertEqual(content, "hello")
    }

    func testCopyOverwriteReplacesDestination() async throws {
        let provider = LocalFileSystemProvider()
        let srcURL = try fixture.makeFile(name: "src.txt", content: "new")
        let destDir = self.fixture.url.appendingPathComponent("dest", isDirectory: true)
        try FileManager().createDirectory(at: destDir, withIntermediateDirectories: true)
        try "old".write(to: destDir.appendingPathComponent("src.txt"), atomically: true, encoding: .utf8)

        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let destPath = FilePath(scheme: .local, posix: destDir.path)
        let op = OperationDescriptor(kind: .copy, sources: [srcPath], destination: destPath, conflictPolicy: .overwrite)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        let content = try String(contentsOf: destDir.appendingPathComponent("src.txt"), encoding: .utf8)
        XCTAssertEqual(content, "new")
    }

    func testCopyRenameCreatesUniqueDestination() async throws {
        let provider = LocalFileSystemProvider()
        let srcURL = try fixture.makeFile(name: "file.txt", content: "new")
        let destDir = self.fixture.url.appendingPathComponent("dest", isDirectory: true)
        try FileManager().createDirectory(at: destDir, withIntermediateDirectories: true)
        try "old".write(to: destDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let destPath = FilePath(scheme: .local, posix: destDir.path)
        let op = OperationDescriptor(kind: .copy, sources: [srcPath], destination: destPath, conflictPolicy: .rename)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        // Both original and renamed copy exist
        XCTAssertTrue(FileManager().fileExists(atPath: destDir.appendingPathComponent("file.txt").path))
        XCTAssertTrue(FileManager().fileExists(atPath: destDir.appendingPathComponent("file 2.txt").path))
    }

    // MARK: - move

    func testMoveRemovesSource() async throws {
        let provider = LocalFileSystemProvider()
        let srcURL = try fixture.makeFile(name: "tomove.txt", content: "data")
        let destDir = self.fixture.path.appending("moved")
        _ = try self.fixture.makeSubdirectory(name: "moved")

        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let op = OperationDescriptor(kind: .move, sources: [srcPath], destination: destDir)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertFalse(FileManager().fileExists(atPath: srcURL.path), "Source should be gone after move")
        XCTAssertTrue(FileManager()
            .fileExists(atPath: self.fixture.url.appendingPathComponent("moved/tomove.txt").path))
    }

    // MARK: - delete

    func testDeleteRemovesFile() async throws {
        let provider = LocalFileSystemProvider()
        let fileURL = try fixture.makeFile(name: "del.txt")
        let filePath = FilePath(scheme: .local, posix: fileURL.path)
        let op = OperationDescriptor(kind: .delete, sources: [filePath])
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertFalse(FileManager().fileExists(atPath: fileURL.path))
    }

    func testDeleteIsIdempotentForMissingFiles() async throws {
        let provider = LocalFileSystemProvider()
        let missing = FilePath(scheme: .local, posix: fixture.url.appendingPathComponent("ghost.txt").path)
        let op = OperationDescriptor(kind: .delete, sources: [missing])
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.itemsProcessed, 0)
    }

    // MARK: - rename

    func testRenameUpdatesPath() async throws {
        let provider = LocalFileSystemProvider()
        let srcURL = try fixture.makeFile(name: "before.txt")
        let destPath = FilePath(scheme: .local, posix: fixture.url.appendingPathComponent("after.txt").path)
        let srcPath = FilePath(scheme: .local, posix: srcURL.path)
        let op = OperationDescriptor(kind: .rename, sources: [srcPath], destination: destPath)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertFalse(FileManager().fileExists(atPath: srcURL.path))
        XCTAssertTrue(FileManager().fileExists(atPath: destPath.posixString))
    }

    // MARK: - symlink

    func testSymlinkCreatesLink() async throws {
        let provider = LocalFileSystemProvider()
        let targetURL = try fixture.makeFile(name: "target.txt")
        let linkPath = FilePath(scheme: .local, posix: fixture.url.appendingPathComponent("link.txt").path)
        let targetPath = FilePath(scheme: .local, posix: targetURL.path)
        let op = OperationDescriptor(kind: .symlink, sources: [targetPath], destination: linkPath)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        let dest = try FileManager().destinationOfSymbolicLink(atPath: linkPath.posixString)
        XCTAssertEqual(dest, targetURL.path)
    }

    // MARK: - trash

    func testTrashMovesToTrash() async throws {
        let provider = LocalFileSystemProvider()
        let fileURL = try fixture.makeFile(name: "trash_me.txt")
        let filePath = FilePath(scheme: .local, posix: fileURL.path)
        let op = OperationDescriptor(kind: .trash, sources: [filePath])
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertFalse(FileManager().fileExists(atPath: fileURL.path))
    }

    // MARK: - Progress reporting

    func testProgressCallbackFiresPreparingAndCompleted() async throws {
        let provider = LocalFileSystemProvider()
        _ = try self.fixture.makeSubdirectory(name: "prog")
        let newDir = self.fixture.path.appending("prog").appending("sub")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: newDir)
        let recorder = ProgressRecorder()
        _ = try await provider.execute(op, progress: recorder)
        let phases = await recorder.phases
        XCTAssertTrue(phases.contains(.preparing))
        XCTAssertTrue(phases.contains(.completed))
    }
}

// MARK: - Test helper

private actor ProgressRecorder: OperationProgressReporting {
    private(set) var phases: [Core.Progress.Phase] = []

    nonisolated func report(_ progress: Core.Progress) async {
        await self.append(progress.phase)
    }

    private func append(_ phase: Core.Progress.Phase) {
        self.phases.append(phase)
    }
}
