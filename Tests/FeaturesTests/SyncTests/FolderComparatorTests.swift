import Core
import FeaturesSync
import Foundation
import XCTest

// MARK: - ComparatorFixture

private struct ComparatorFixture {
    let comparator: FolderComparator
    let left: InMemorySyncProvider
    let right: InMemorySyncProvider
}

// MARK: - FolderComparatorTests

final class FolderComparatorTests: XCTestCase {
    private let leftRoot = FilePath(scheme: .local, posix: "/left")
    private let rightRoot = FilePath(scheme: .local, posix: "/right")

    private func makeComparator(options: SyncOptions = .default) async -> ComparatorFixture {
        let left = InMemorySyncProvider(scheme: .local)
        let right = InMemorySyncProvider(scheme: .local)
        let comparator = FolderComparator(leftProvider: left, rightProvider: right, options: options)
        return ComparatorFixture(comparator: comparator, left: left, right: right)
    }

    // MARK: - Basic cases

    func testEmptyBothSides() async throws {
        let f = await makeComparator()
        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertTrue(diffs.isEmpty)
    }

    func testIdenticalTrees() async throws {
        let f = await makeComparator()
        let data = Data("hello".utf8)
        let mtime = Date(timeIntervalSince1970: 1_000_000)
        await f.left.seed(data, at: FilePath(scheme: .local, posix: "/left/foo.txt"), mtime: mtime)
        await f.right.seed(data, at: FilePath(scheme: .local, posix: "/right/foo.txt"), mtime: mtime)

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].status, .matched)
    }

    func testLeftOnlyItem() async throws {
        let f = await makeComparator()
        await f.left.seed(Data("x".utf8), at: FilePath(scheme: .local, posix: "/left/only.txt"))

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].status, .leftOnly)
        XCTAssertNotNil(diffs[0].leftItem)
        XCTAssertNil(diffs[0].rightItem)
    }

    func testRightOnlyItem() async throws {
        let f = await makeComparator()
        await f.right.seed(Data("x".utf8), at: FilePath(scheme: .local, posix: "/right/only.txt"))

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].status, .rightOnly)
        XCTAssertNil(diffs[0].leftItem)
        XCTAssertNotNil(diffs[0].rightItem)
    }

    // MARK: - Modified detection

    func testModifiedBySizeDifference() async throws {
        let mtime = Date(timeIntervalSince1970: 1_000_000)
        let f = await makeComparator()
        await f.left.seed(Data("hello".utf8), at: FilePath(scheme: .local, posix: "/left/foo.txt"), mtime: mtime)
        await f.right.seed(Data("hi".utf8), at: FilePath(scheme: .local, posix: "/right/foo.txt"), mtime: mtime)

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertEqual(diffs[0].status, .modified)
    }

    func testModifiedByMtimeDifference() async throws {
        let data = Data(repeating: 0x01, count: 100)
        let f = await makeComparator()
        await f.left.seed(
            data,
            at: FilePath(scheme: .local, posix: "/left/foo.txt"),
            mtime: Date(timeIntervalSince1970: 1_000_000)
        )
        await f.right.seed(
            data,
            at: FilePath(scheme: .local, posix: "/right/foo.txt"),
            mtime: Date(timeIntervalSince1970: 2_000_000)
        )

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertEqual(diffs[0].status, .modified)
    }

    func testMatchedWithinMtimeTolerance() async throws {
        let data = Data(repeating: 0x01, count: 100)
        let opts = SyncOptions(mtimeTolerance: 5.0)
        let f = await makeComparator(options: opts)
        await f.left.seed(
            data,
            at: FilePath(scheme: .local, posix: "/left/foo.txt"),
            mtime: Date(timeIntervalSince1970: 1_000_000)
        )
        await f.right.seed(
            data,
            at: FilePath(scheme: .local, posix: "/right/foo.txt"),
            mtime: Date(timeIntervalSince1970: 1_000_003)
        )

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertEqual(diffs[0].status, .matched)
    }

    func testMatchedSizeTolerance() async throws {
        let mtime = Date(timeIntervalSince1970: 1_000_000)
        let opts = SyncOptions(sizeTolerance: 10)
        let f = await makeComparator(options: opts)
        await f.left.seed(
            Data(repeating: 0x01, count: 100),
            at: FilePath(scheme: .local, posix: "/left/foo.txt"),
            mtime: mtime
        )
        await f.right.seed(
            Data(repeating: 0x01, count: 105),
            at: FilePath(scheme: .local, posix: "/right/foo.txt"),
            mtime: mtime
        )

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertEqual(diffs[0].status, .matched)
    }

    // MARK: - Ignore globs

    func testIgnoreGlobExcludesLeftItem() async throws {
        let opts = SyncOptions(ignoreGlobs: ["*.DS_Store"])
        let f = await makeComparator(options: opts)
        await f.left.seed(Data("x".utf8), at: FilePath(scheme: .local, posix: "/left/.DS_Store"))
        await f.left.seed(Data("y".utf8), at: FilePath(scheme: .local, posix: "/left/keep.txt"))

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertFalse(diffs.contains { $0.relativePath.lastComponent == ".DS_Store" })
        XCTAssertTrue(diffs.contains { $0.relativePath.lastComponent == "keep.txt" })
    }

    func testIgnoreGlobExcludesRightItem() async throws {
        let opts = SyncOptions(ignoreGlobs: ["*.log"])
        let f = await makeComparator(options: opts)
        await f.right.seed(Data("log".utf8), at: FilePath(scheme: .local, posix: "/right/debug.log"))

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertTrue(diffs.isEmpty)
    }

    // MARK: - Deep hash

    func testDeepHashMatchedSameContent() async throws {
        let opts = SyncOptions(useDeepHash: true)
        let f = await makeComparator(options: opts)
        let data = Data("same content".utf8)
        // Different mtimes — fast path would call .modified, but deep hash should return .matched
        await f.left.seed(
            data,
            at: FilePath(scheme: .local, posix: "/left/foo.txt"),
            mtime: Date(timeIntervalSince1970: 1_000_000)
        )
        await f.right.seed(
            data,
            at: FilePath(scheme: .local, posix: "/right/foo.txt"),
            mtime: Date(timeIntervalSince1970: 9_000_000)
        )

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertEqual(diffs[0].status, .matched)
    }

    func testDeepHashModifiedDifferentContent() async throws {
        let opts = SyncOptions(useDeepHash: true)
        let f = await makeComparator(options: opts)
        let mtime = Date(timeIntervalSince1970: 1_000_000)
        await f.left.seed(Data("content A".utf8), at: FilePath(scheme: .local, posix: "/left/foo.txt"), mtime: mtime)
        await f.right.seed(Data("content B".utf8), at: FilePath(scheme: .local, posix: "/right/foo.txt"), mtime: mtime)

        let diffs = try await f.comparator.compare(leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        XCTAssertEqual(diffs[0].status, .modified)
    }

    // MARK: - Cancellation

    func testDeepHashCancellationHalts() async throws {
        let slowLeft = SlowChunkProvider(scheme: .local, chunkDelayNs: 50_000_000)
        let slowRight = SlowChunkProvider(scheme: .local, chunkDelayNs: 50_000_000)

        // Use data larger than defaultChunkSize (262144) so multiple slow chunks are needed.
        let data = Data(repeating: 0x01, count: 600_000)
        await slowLeft.seed(data, at: FilePath(scheme: .local, posix: "/left/big.bin"))
        await slowRight.seed(data, at: FilePath(scheme: .local, posix: "/right/big.bin"))

        let opts = SyncOptions(useDeepHash: true)
        let comparator = FolderComparator(leftProvider: slowLeft, rightProvider: slowRight, options: opts)

        let task = Task<[Difference], any Error> {
            try await comparator.compare(
                leftRoot: FilePath(scheme: .local, posix: "/left"),
                rightRoot: FilePath(scheme: .local, posix: "/right")
            )
        }

        try await Task.sleep(nanoseconds: 60_000_000) // 60 ms — after first chunk
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError or task cancellation")
        } catch is CancellationError {
            // Expected
        } catch {
            // Also acceptable — the task may throw before reaching the hash
        }
    }
}

// MARK: - SlowChunkProvider

/// A `SyncReadableProvider` that introduces per-chunk delays for cancellation tests.
private final actor SlowChunkProvider: SyncReadableProvider {
    nonisolated let scheme: ConnectionScheme
    private var store: [FilePath: Data] = [:]
    private let chunkDelayNs: UInt64

    init(scheme: ConnectionScheme, chunkDelayNs: UInt64) {
        self.scheme = scheme
        self.chunkDelayNs = chunkDelayNs
    }

    func seed(_ data: Data, at path: FilePath) {
        self.store[path] = data
    }

    func attributes(at path: FilePath) async throws -> FileAttributes {
        guard let data = self.store[path] else {
            throw StevedoreError.fileSystem(.notFound(path))
        }
        return FileAttributes(sizeInBytes: Int64(data.count))
    }

    nonisolated func enumerate(
        at path: FilePath,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else { continuation.finish()
                    return
                }
                let items = await self.allItems(under: path)
                for item in items {
                    continuation.yield(item)
                }
                continuation.finish()
            }
        }
    }

    func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        OperationResult(descriptorID: operation.id, status: .completed, bytesProcessed: 0, itemsProcessed: 0)
    }

    nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream { $0.finish() }
    }

    nonisolated func readChunks(at path: FilePath, chunkSize: Int) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else { continuation.finish()
                    return
                }
                let delay = self.chunkDelayNs
                guard let data = await self.store[path] else {
                    continuation.finish(throwing: StevedoreError.fileSystem(.notFound(path)))
                    return
                }
                var offset = 0
                while offset < data.count {
                    if Task.isCancelled { continuation.finish()
                        return
                    }
                    try? await Task.sleep(nanoseconds: delay)
                    if Task.isCancelled { continuation.finish()
                        return
                    }
                    let end = min(offset + chunkSize, data.count)
                    continuation.yield(data[offset ..< end])
                    offset = end
                }
                continuation.finish()
            }
        }
    }

    private func allItems(under root: FilePath) -> [FileItem] {
        self.store.compactMap { path, data -> FileItem? in
            guard path.scheme == root.scheme,
                  let rel = path.relative(to: root), !rel.isEmpty
            else { return nil }
            return FileItem(
                path: path,
                kind: .regularFile,
                attributes: FileAttributes(sizeInBytes: Int64(data.count))
            )
        }
    }
}
