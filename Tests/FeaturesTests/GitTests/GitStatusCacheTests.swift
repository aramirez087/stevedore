import Core
import FeaturesGit
import Foundation
import XCTest

final class GitStatusCacheTests: XCTestCase {
    override func setUpWithError() throws {
        try skipIfGitMissing()
    }

    private let dummyRoot = FilePath(scheme: .local, posix: "/tmp/test-repo")

    func testCacheHit() async throws {
        let cache = GitStatusCache()
        let counter = Counter()

        let fetch: @Sendable () async throws -> [GitFileStatus] = {
            await counter.increment()
            return []
        }

        _ = try await cache.getOrFetch(repoRoot: dummyRoot, fetch: fetch)
        _ = try await cache.getOrFetch(repoRoot: dummyRoot, fetch: fetch)

        let count = await counter.value
        XCTAssertEqual(count, 1, "fetch should be called only once on cache hit")
    }

    func testManualInvalidation() async throws {
        let cache = GitStatusCache()
        let counter = Counter()

        let fetch: @Sendable () async throws -> [GitFileStatus] = {
            await counter.increment()
            return []
        }

        _ = try await cache.getOrFetch(repoRoot: dummyRoot, fetch: fetch)
        let countAfterFirst = await counter.value
        XCTAssertEqual(countAfterFirst, 1)

        await cache.invalidate(repoRoot: dummyRoot)

        _ = try await cache.getOrFetch(repoRoot: dummyRoot, fetch: fetch)
        let countAfterSecond = await counter.value
        XCTAssertEqual(countAfterSecond, 2, "fetch should be called again after invalidation")
    }

    func testCacheMissAfterInvalidate() async throws {
        let cache = GitStatusCache()
        let counter = Counter()

        let fetch: @Sendable () async throws -> [GitFileStatus] = {
            await counter.increment()
            return []
        }

        _ = try await cache.getOrFetch(repoRoot: dummyRoot, fetch: fetch)
        await cache.invalidate(repoRoot: dummyRoot)
        _ = try await cache.getOrFetch(repoRoot: dummyRoot, fetch: fetch)

        let count = await counter.value
        XCTAssertEqual(count, 2)
    }

    func testFSEventsInvalidation() async throws {
        let repo = try await GitTestRepo.create()
        defer { repo.tearDown() }

        // Seed the repo with a tracked file.
        try await repo.makeAndStage(file: "tracked.txt", content: "original\n")
        try await repo.commit(message: "initial")

        let cache = GitStatusCache()
        let counter = Counter()

        let root = repo.rootPath
        let rootURL = repo.rootURL
        let fetch: @Sendable () async throws -> [GitFileStatus] = {
            await counter.increment()
            let result = try await GitProcess.run(
                arguments: ["status", "--porcelain=v2", "-z", "--untracked-files=all", "--ignored=matching"],
                workingDirectory: rootURL
            )
            return GitStatusParser.parse(result.stdout, repoRoot: root)
        }

        // Seed cache.
        _ = try await cache.getOrFetch(repoRoot: root, fetch: fetch)
        let countAfterSeed = await counter.value
        XCTAssertEqual(countAfterSeed, 1)

        // Modify the tracked file — this triggers an FSEvent.
        try repo.modifyFile(name: "tracked.txt", content: "modified\n")

        // Wait 250ms for FSEvents latency (50ms) + processing overhead.
        try await Task.sleep(for: .milliseconds(250))

        // Cache should be stale now.
        _ = try await cache.getOrFetch(repoRoot: root, fetch: fetch)
        let countAfterInvalidation = await counter.value
        XCTAssertEqual(countAfterInvalidation, 2, "cache should have been invalidated by FSEvents within 200ms")
    }

    func testConcurrentFetch() async throws {
        let cache = GitStatusCache()
        let counter = Counter()
        // Extract to local so `async let` doesn't capture `self`.
        let repoRoot = dummyRoot

        let fetch: @Sendable () async throws -> [GitFileStatus] = {
            await counter.increment()
            // Simulate a short async operation.
            try await Task.sleep(for: .milliseconds(50))
            return []
        }

        async let r1 = cache.getOrFetch(repoRoot: repoRoot, fetch: fetch)
        async let r2 = cache.getOrFetch(repoRoot: repoRoot, fetch: fetch)
        _ = try await (r1, r2)

        let count = await counter.value
        XCTAssertEqual(count, 1, "concurrent getOrFetch calls should share one in-flight fetch")
    }
}

// MARK: - Helpers

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
