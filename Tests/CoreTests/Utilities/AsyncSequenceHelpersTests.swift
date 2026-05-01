@testable import Core
import XCTest

/// Actor-isolated collector for @Sendable async closures in tests.
private actor ProgressCollector {
    private(set) var items: [Core.Progress] = []
    func append(_ p: Core.Progress) {
        self.items.append(p)
    }
}

final class AsyncSequenceHelpersTests: XCTestCase {
    // MARK: - chunked(by:)

    func testChunked_evenlySplits() async throws {
        let stream = AsyncStream<Int> { continuation in
            for i in 1 ... 6 {
                continuation.yield(i)
            }
            continuation.finish()
        }
        var chunks: [[Int]] = []
        for try await chunk in stream.chunked(by: 2) {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, [[1, 2], [3, 4], [5, 6]])
    }

    func testChunked_partialTrailingBatch() async throws {
        let stream = AsyncStream<Int> { continuation in
            for i in 1 ... 5 {
                continuation.yield(i)
            }
            continuation.finish()
        }
        var chunks: [[Int]] = []
        for try await chunk in stream.chunked(by: 2) {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, [[1, 2], [3, 4], [5]])
    }

    func testChunked_singleElement() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("hello")
            continuation.finish()
        }
        var chunks: [[String]] = []
        for try await chunk in stream.chunked(by: 10) {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, [["hello"]])
    }

    func testChunked_emptyStream() async throws {
        let stream = AsyncStream<Int> { continuation in
            continuation.finish()
        }
        var chunks: [[Int]] = []
        for try await chunk in stream.chunked(by: 3) {
            chunks.append(chunk)
        }
        XCTAssertTrue(chunks.isEmpty)
    }

    // MARK: - throttled(for:)

    func testThrottled_deliversAllElements() async throws {
        let stream = AsyncStream<Int> { continuation in
            for i in 1 ... 5 {
                continuation.yield(i)
            }
            continuation.finish()
        }
        var received: [Int] = []
        // Very short interval so throttle doesn't discard in tests.
        for try await value in stream.throttled(for: .milliseconds(1)) {
            received.append(value)
        }
        // Throttle keeps the LAST in each window + always delivers final.
        XCTAssertFalse(received.isEmpty)
        XCTAssertTrue(received.contains(5), "Final element must always be delivered")
    }

    // MARK: - withProgress(_:)

    func testWithProgress_reportsProgress() async throws {
        let stream = AsyncStream<FileItem> { continuation in
            let item = FileItem(
                path: FilePath(scheme: .local, posix: "/file"),
                kind: .regularFile,
                attributes: FileAttributes(sizeInBytes: 1024)
            )
            continuation.yield(item)
            continuation.finish()
        }

        let collector = ProgressCollector()
        let proxied = stream.withProgress(bytesTotal: 2048, phase: .transferring) { progress in
            await collector.append(progress)
        }

        var received: [FileItem] = []
        for try await item in proxied {
            received.append(item)
        }

        let reports = await collector.items
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports[0].bytesDone, 1024)
        XCTAssertEqual(reports[0].bytesTotal, 2048)
    }

    func testWithProgress_itemCountFallback() async throws {
        // Elements are plain Ints (not FileItem), so item count is used.
        let stream = AsyncStream<Int> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.finish()
        }
        let collector = ProgressCollector()
        for try await _ in stream.withProgress(report: { await collector.append($0) }) {}
        let last = await collector.items.last
        XCTAssertEqual(last?.bytesDone, 2, "Expected item count in bytesDone")
    }

    func testWithProgress_forwardsElements() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("a")
            continuation.yield("b")
            continuation.finish()
        }
        var elements: [String] = []
        for try await el in stream.withProgress(report: { _ in }) {
            elements.append(el)
        }
        XCTAssertEqual(elements, ["a", "b"])
    }
}
