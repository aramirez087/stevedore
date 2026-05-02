import Core
import FeaturesGit
import Foundation
import XCTest

// MARK: - Skip helper

func skipIfGitMissing() throws {
    guard FileManager.default.isExecutableFile(atPath: GitProcess.executablePath) else {
        throw XCTSkip("/usr/bin/git not found — skipping git tests")
    }
}

// MARK: - GitTestRepo

/// Manages a temporary git repository for integration tests.
///
/// Marked `@unchecked Sendable` because all mutable state is either
/// immutable after construction or accessed only from async test contexts
/// that are sequenced by `XCTest`.
final class GitTestRepo: @unchecked Sendable {
    let rootURL: URL
    let rootPath: FilePath

    private init(url: URL) {
        self.rootURL = url
        self.rootPath = FilePath(scheme: .local, posix: url.path)
    }

    static func create() async throws -> GitTestRepo {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("stevedore-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let repo = GitTestRepo(url: dir)
        try await repo.git("init")
        try await repo.git("config", "user.email", "test@stevedore.test")
        try await repo.git("config", "user.name", "Stevedore Test")
        return repo
    }

    func tearDown() {
        try? FileManager.default.removeItem(at: self.rootURL)
    }

    // MARK: - Helpers

    @discardableResult
    func makeFile(name: String, content: String = "content\n") throws -> URL {
        let url = self.rootURL.appendingPathComponent(name)
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func makeAndStage(file name: String, content: String = "content\n") async throws {
        try self.makeFile(name: name, content: content)
        try await self.git("add", name)
    }

    func commit(message: String = "test commit") async throws {
        try await self.git("commit", "-m", message)
    }

    func modifyFile(name: String, content: String = "modified\n") throws {
        let url = self.rootURL.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func deleteFile(name: String) throws {
        try FileManager.default.removeItem(at: self.rootURL.appendingPathComponent(name))
    }

    func addToGitignore(pattern: String) async throws {
        let existing = (try? String(contentsOf: self.rootURL.appendingPathComponent(".gitignore"), encoding: .utf8)) ??
            ""
        try (existing + pattern + "\n").write(
            to: self.rootURL.appendingPathComponent(".gitignore"),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Private

    @discardableResult
    func git(_ args: String...) async throws -> GitProcess.Result {
        let result = try await GitProcess.run(arguments: Array(args), workingDirectory: self.rootURL)
        if result.exitCode != 0 {
            let err = String(bytes: result.stderr, encoding: .utf8) ?? ""
            throw GitTestError.gitFailed(args: Array(args), stderr: err)
        }
        return result
    }
}

enum GitTestError: Error {
    case gitFailed(args: [String], stderr: String)
}
