import Core
import FeaturesGit
import Foundation
import XCTest

final class GitStatusProviderTests: XCTestCase {
    private var repo: GitTestRepo!
    private var service: GitStatusService!

    override func setUpWithError() throws {
        try skipIfGitMissing()
    }

    override func setUp() async throws {
        self.repo = try await GitTestRepo.create()
        self.service = GitStatusService()
    }

    override func tearDown() {
        self.repo.tearDown()
        self.repo = nil
        self.service = nil
    }

    func testCleanRepo() async throws {
        try await self.repo.makeAndStage(file: "clean.txt")
        try await self.repo.commit(message: "initial")

        let statuses = try await service.status(under: self.repo.rootPath)
        // No dirty files; nothing should appear (clean files are not emitted).
        XCTAssertTrue(statuses.isEmpty || statuses.allSatisfy {
            $0.indexState == .unmodified && $0.worktreeState == .unmodified
        })
    }

    func testDirtyFile() async throws {
        try await self.repo.makeAndStage(file: "file.txt", content: "original\n")
        try await self.repo.commit(message: "initial")
        try self.repo.modifyFile(name: "file.txt", content: "dirty\n")

        let statuses = try await service.status(under: self.repo.rootPath)
        let entry = statuses.first { $0.path.lastComponent == "file.txt" }
        XCTAssertNotNil(entry, "should report modified file")
        XCTAssertEqual(entry?.worktreeState, .modified)
    }

    func testStagedFile() async throws {
        try await self.repo.makeAndStage(file: "staged.txt", content: "v1\n")
        try await self.repo.commit(message: "initial")
        try self.repo.modifyFile(name: "staged.txt", content: "v2\n")
        try await self.repo.git("add", "staged.txt")

        let statuses = try await service.status(under: self.repo.rootPath)
        let entry = statuses.first { $0.path.lastComponent == "staged.txt" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.indexState, .modified)
    }

    func testDeletedFile() async throws {
        try await self.repo.makeAndStage(file: "gone.txt")
        try await self.repo.commit(message: "initial")
        try self.repo.deleteFile(name: "gone.txt")

        let statuses = try await service.status(under: self.repo.rootPath)
        let entry = statuses.first { $0.path.lastComponent == "gone.txt" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.worktreeState, .deleted)
    }

    func testStagedDeletion() async throws {
        try await self.repo.makeAndStage(file: "remove.txt")
        try await self.repo.commit(message: "initial")
        try await self.repo.git("rm", "remove.txt")

        let statuses = try await service.status(under: self.repo.rootPath)
        let entry = statuses.first { $0.path.lastComponent == "remove.txt" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.indexState, .deleted)
    }

    func testRenamedFile() async throws {
        try await self.repo.makeAndStage(file: "old.txt")
        try await self.repo.commit(message: "initial")
        try await self.repo.git("mv", "old.txt", "new.txt")

        let statuses = try await service.status(under: self.repo.rootPath)
        let entry = statuses.first { $0.path.lastComponent == "new.txt" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.indexState, .renamed)
    }

    func testUntrackedFile() async throws {
        try await self.repo.makeAndStage(file: "tracked.txt")
        try await self.repo.commit(message: "initial")
        try self.repo.makeFile(name: "untracked.txt")

        let statuses = try await service.status(under: self.repo.rootPath)
        let entry = statuses.first { $0.path.lastComponent == "untracked.txt" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.worktreeState, .untracked)
    }

    func testIgnoredFile() async throws {
        try await self.repo.makeAndStage(file: "tracked.txt")
        try await self.repo.commit(message: "initial")
        try await self.repo.addToGitignore(pattern: "*.log")
        try self.repo.makeFile(name: "ignored.log")

        let statuses = try await service.status(under: self.repo.rootPath)
        let entry = statuses.first { $0.path.lastComponent == "ignored.log" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.worktreeState, .ignored)
    }

    func testRepositoryRootResolution() async throws {
        let subdir = self.repo.rootURL.appendingPathComponent("sub/dir")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let subdirPath = FilePath(scheme: .local, posix: subdir.path)
        let root = await service.repositoryRoot(for: subdirPath)

        XCTAssertNotNil(root)
        XCTAssertEqual(root?.posixString, self.repo.rootPath.posixString)
    }

    func testNonGitDirectory() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let path = FilePath(scheme: .local, posix: tmpDir.path)
        let statuses = try await service.status(under: path)
        XCTAssertEqual(statuses, [])
    }

    func testStatusFilteredToSubdirectory() async throws {
        try await self.repo.makeAndStage(file: "root.txt", content: "r\n")
        try FileManager.default.createDirectory(
            at: self.repo.rootURL.appendingPathComponent("sub"),
            withIntermediateDirectories: true
        )
        try await self.repo.makeAndStage(file: "sub/nested.txt", content: "n\n")
        try await self.repo.commit(message: "initial")

        // Modify only the nested file.
        try self.repo.modifyFile(name: "sub/nested.txt", content: "modified\n")

        let subPath = FilePath(scheme: .local, posix: repo.rootURL.appendingPathComponent("sub").path)
        let statuses = try await service.status(under: subPath)

        XCTAssertTrue(statuses.allSatisfy { $0.path.posixString.hasPrefix(subPath.posixString) },
                      "All returned statuses should be under the sub directory")
    }
}
