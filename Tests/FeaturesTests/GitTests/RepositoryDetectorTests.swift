import Core
import FeaturesGit
import Foundation
import XCTest

final class RepositoryDetectorTests: XCTestCase {
    override func setUpWithError() throws {
        try skipIfGitMissing()
    }

    func testFindsRootFromSubdirectory() async throws {
        let repo = try await GitTestRepo.create()
        defer { repo.tearDown() }

        let subdir = repo.rootURL.appendingPathComponent("a/b/c")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let subdirPath = FilePath(scheme: .local, posix: subdir.path)
        let found = RepositoryDetector.findRoot(for: subdirPath)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.posixString, repo.rootPath.posixString)
    }

    func testReturnsNilOutsideRepo() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-repo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let path = FilePath(scheme: .local, posix: tmpDir.path)
        XCTAssertNil(RepositoryDetector.findRoot(for: path))
    }

    func testFindsRootAtPath() async throws {
        let repo = try await GitTestRepo.create()
        defer { repo.tearDown() }

        let found = RepositoryDetector.findRoot(for: repo.rootPath)
        XCTAssertEqual(found?.posixString, repo.rootPath.posixString)
    }

    func testWorktreeLinkfile() throws {
        // Create a directory with a `.git` file (not a directory) — simulates a worktree.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("worktree-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dotGit = tmpDir.appendingPathComponent(".git")
        try "gitdir: /some/other/path/.git/worktrees/foo\n"
            .write(to: dotGit, atomically: true, encoding: .utf8)

        let path = FilePath(scheme: .local, posix: tmpDir.path)
        let found = RepositoryDetector.findRoot(for: path)

        // The containing directory is treated as the working-tree root.
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.posixString, path.posixString)
    }

    func testNonLocalSchemeReturnsNil() {
        let path = FilePath(scheme: .sftp, posix: "/home/user/project")
        XCTAssertNil(RepositoryDetector.findRoot(for: path))
    }
}
