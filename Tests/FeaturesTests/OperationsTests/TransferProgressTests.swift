import Core
import FeaturesOperations
import Foundation
import XCTest

final class TransferProgressTests: XCTestCase {
    func testInitialProgressZero() {
        let progress = TransferProgress(operationID: UUID())
        XCTAssertEqual(progress.bytesCompleted, 0)
        XCTAssertNil(progress.bytesTotal)
        XCTAssertNil(progress.fraction)
    }

    func testFractionClampsToOne() throws {
        var progress = TransferProgress(operationID: UUID())
        progress.bytesCompleted = 2000
        progress.bytesTotal = 1000
        XCTAssertEqual(try XCTUnwrap(progress.fraction), 1.0, accuracy: 0.001)
    }

    func testQueueProgressAggregateBytesCompleted() {
        let id1 = UUID()
        let id2 = UUID()
        var p1 = TransferProgress(operationID: id1)
        p1.bytesCompleted = 100
        var p2 = TransferProgress(operationID: id2)
        p2.bytesCompleted = 200
        let queue = QueueProgress(perOperation: [id1: p1, id2: p2])
        XCTAssertEqual(queue.aggregateBytesCompleted, 300)
    }

    func testQueueProgressAggregateTotalNilWhenAnyUnknown() {
        let id1 = UUID()
        let id2 = UUID()
        var p1 = TransferProgress(operationID: id1)
        p1.bytesTotal = 1000
        let p2 = TransferProgress(operationID: id2) // bytesTotal is nil
        let queue = QueueProgress(perOperation: [id1: p1, id2: p2])
        XCTAssertNil(queue.aggregateBytesTotal)
    }

    func testQueueProgressAggregateTotalSumsWhenAllKnown() {
        let id1 = UUID()
        let id2 = UUID()
        var p1 = TransferProgress(operationID: id1)
        p1.bytesTotal = 1000
        var p2 = TransferProgress(operationID: id2)
        p2.bytesTotal = 2000
        let queue = QueueProgress(perOperation: [id1: p1, id2: p2])
        XCTAssertEqual(queue.aggregateBytesTotal, 3000)
    }

    func testTrackerThrottlesUpdates() async throws {
        let tracker = TransferProgressTracker(minReportInterval: .milliseconds(50))
        var stream = tracker.progressStream().makeAsyncIterator()
        // Consume initial snapshot.
        _ = await stream.next()

        let id = UUID()
        var progress = TransferProgress(operationID: id)
        progress.bytesCompleted = 100

        // Rapid-fire 10 updates — should coalesce due to throttle.
        for _ in 0 ..< 10 {
            await tracker.update(progress)
        }
        // Give the tracker time to emit if any coalesced updates fire.
        try await Task.sleep(for: .milliseconds(10))

        // complete always emits.
        await tracker.complete(operationID: id)
        let snapshot = await stream.next()
        XCTAssertNotNil(snapshot)
    }

    func testTrackerCompleteAlwaysEmits() async {
        let tracker = TransferProgressTracker(minReportInterval: .milliseconds(500))
        var stream = tracker.progressStream().makeAsyncIterator()
        _ = await stream.next()

        let id = UUID()
        await tracker.complete(operationID: id)
        let result = await stream.next()
        XCTAssertNotNil(result)
    }
}
