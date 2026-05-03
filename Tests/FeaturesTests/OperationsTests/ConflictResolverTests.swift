import Core
import FeaturesOperations
import Foundation
import XCTest

final class ConflictResolverTests: XCTestCase {
    func testSkipPolicy() async {
        let src = FilePath.local("/a/file.txt")
        let dst = FilePath.local("/b/file.txt")
        let resolver = ConflictResolver()
        let result = await resolver.resolve(source: src, destination: dst, policy: .skip)
        XCTAssertEqual(result, .skip)
    }

    func testOverwritePolicy() async {
        let src = FilePath.local("/a/file.txt")
        let dst = FilePath.local("/b/file.txt")
        let resolver = ConflictResolver()
        let result = await resolver.resolve(source: src, destination: dst, policy: .overwrite)
        XCTAssertEqual(result, .replace)
    }

    func testRenamePolicy() async {
        let src = FilePath.local("/a/file.txt")
        let dst = FilePath.local("/b/file.txt")
        let resolver = ConflictResolver()
        let result = await resolver.resolve(source: src, destination: dst, policy: .rename)
        XCTAssertEqual(result, .renameWithSuffix)
    }

    func testAskSuspendsAndResolvesOnProvide() async throws {
        let src = FilePath.local("/a/file.txt")
        let dst = FilePath.local("/b/file.txt")
        let resolver = ConflictResolver()

        let task = Task { () -> ConflictResolution in
            await resolver.resolve(source: src, destination: dst, policy: .ask)
        }
        try await Task.sleep(for: .milliseconds(10))
        await resolver.provide(resolution: .replace, for: src)
        let result = await task.value
        XCTAssertEqual(result, .replace)
    }

    func testAskSuspendsAndResolvesSkip() async throws {
        let src = FilePath.local("/a/file.txt")
        let dst = FilePath.local("/b/file.txt")
        let resolver = ConflictResolver()

        let task = Task { () -> ConflictResolution in
            await resolver.resolve(source: src, destination: dst, policy: .ask)
        }
        try await Task.sleep(for: .milliseconds(10))
        await resolver.provide(resolution: .skip, for: src)
        let result = await task.value
        XCTAssertEqual(result, .skip)
    }

    func testProvideOnUnknownSourceIsNoOp() async {
        let src = FilePath.local("/a/file.txt")
        let resolver = ConflictResolver()
        await resolver.provide(resolution: .replace, for: src)
    }

    func testUniquePathNonConflicting() {
        let path = FilePath.local("/a/b.txt")
        let result = ConflictResolver.uniquePath(for: path, existingPaths: [])
        XCTAssertEqual(result, path)
    }

    func testUniquePathAppendsNumber() {
        let path = FilePath.local("/a/b.txt")
        let existing: Set<FilePath> = [path]
        let result = ConflictResolver.uniquePath(for: path, existingPaths: existing)
        XCTAssertEqual(result.lastComponent, "b (2).txt")
    }

    func testUniquePathIncrementsUntilFree() {
        let path = FilePath.local("/a/b.txt")
        let existing: Set<FilePath> = [
            path,
            FilePath.local("/a/b (2).txt"),
            FilePath.local("/a/b (3).txt"),
        ]
        let result = ConflictResolver.uniquePath(for: path, existingPaths: existing)
        XCTAssertEqual(result.lastComponent, "b (4).txt")
    }
}
