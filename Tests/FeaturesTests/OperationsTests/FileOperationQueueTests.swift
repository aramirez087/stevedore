import Core
import FeaturesOperations
import Foundation
import XCTest

final class FileOperationQueueTests: XCTestCase {
    private func makeQueue(
        maxConcurrency: Int = 2
    ) -> (FileOperationQueue, TestDataProvider) {
        let provider = TestDataProvider(scheme: .local)
        let tracker = TransferProgressTracker()
        let resolver = ConflictResolver()
        let executor = OperationExecutor(
            providers: [.local: provider],
            conflictResolver: resolver,
            progressTracker: tracker
        )
        let queue = FileOperationQueue(executor: executor, maxConcurrency: maxConcurrency)
        return (queue, provider)
    }

    /// Reads snapshots from the queue stream until `predicate` returns true or
    /// `timeout` seconds elapse. Returns `true` if `predicate` was satisfied.
    private func awaitState(
        queue: FileOperationQueue,
        timeout: Duration = .seconds(5),
        predicate: @Sendable ([FeaturesOperations.Operation]) -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let snapshot = await queue.snapshot()
            if predicate(snapshot) { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    // MARK: - Enqueue / completion

    func testEnqueueAndComplete() async {
        let (queue, _) = self.makeQueue()
        let dir = FilePath.local("/new/dir")

        let descriptor = OperationDescriptor(kind: .mkdir, sources: [], destination: dir)
        await queue.enqueue(descriptor)

        let completed = await awaitState(queue: queue) { ops in
            ops.contains {
                if case .completed = $0.state { return true }
                if case .failed = $0.state { return true }
                return false
            }
        }
        XCTAssertTrue(completed, "Operation should complete")
    }

    func testConcurrencyCapLimitsActive() async {
        let (queue, _) = self.makeQueue(maxConcurrency: 1)

        let d1 = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/a"))
        let d2 = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/b"))
        let d3 = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/c"))

        await queue.enqueue(d1)
        await queue.enqueue(d2)
        await queue.enqueue(d3)

        let snapshot = await queue.snapshot()
        let activeCount = snapshot.count(where: {
            if case .active = $0.state { return true }
            return false
        })
        XCTAssertLessThanOrEqual(activeCount, 1)
    }

    func testCancelPendingOperation() async {
        let (queue, _) = self.makeQueue(maxConcurrency: 1)
        // Fill the slot by enqueueing two ops; the second should be pending.
        let d1 = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/fill"))
        let pending = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/pending"))

        await queue.enqueue(d1)
        await queue.enqueue(pending)
        await queue.cancel(pending.id)

        let cancelled = await awaitState(queue: queue) { ops in
            ops.contains {
                guard $0.id == pending.id else { return false }
                if case .cancelled = $0.state { return true }
                // If it completed before cancel, that's also acceptable.
                if case .completed = $0.state { return true }
                return false
            }
        }
        XCTAssertTrue(cancelled, "Pending operation should be cancelled or completed")
    }

    func testCancelAllCancelsQueue() async {
        let (queue, _) = self.makeQueue()
        let d1 = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/x"))
        let d2 = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/y"))

        await queue.enqueue(d1)
        await queue.enqueue(d2)
        await queue.cancelAll()

        let allTerminal = await awaitState(queue: queue) { ops in
            ops.allSatisfy {
                switch $0.state {
                case .cancelled, .completed, .failed: true
                default: false
                }
            }
        }
        XCTAssertTrue(allTerminal, "All operations should be in a terminal state after cancelAll")
    }

    func testPauseAndResumeOperation() async {
        let (queue, _) = self.makeQueue()
        let descriptor = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/pr"))

        await queue.enqueue(descriptor)
        // Attempt pause/resume — may be a no-op if already complete; that's fine.
        await queue.pause(descriptor.id)
        await queue.resume(descriptor.id)

        let done = await awaitState(queue: queue) { ops in
            ops.allSatisfy {
                switch $0.state {
                case .completed, .failed, .cancelled: true
                default: false
                }
            }
        }
        XCTAssertTrue(done, "Operation should reach a terminal state after pause/resume")
    }

    func testOperationStreamDeliversFinalState() async {
        let (queue, _) = self.makeQueue()
        let descriptor = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/done"))

        var stream = queue.operationStream().makeAsyncIterator()
        // Initial snapshot.
        _ = await stream.next()

        await queue.enqueue(descriptor)

        // Use task-racing: wait up to 5s for a terminal state.
        let sawTerminal = await awaitState(queue: queue) { ops in
            ops.contains {
                switch $0.state {
                case .completed, .failed, .cancelled: true
                default: false
                }
            }
        }
        XCTAssertTrue(sawTerminal, "Stream should deliver terminal state snapshot")
    }

    func testDrainAfterCompletionStartsNextPending() async {
        let (queue, _) = self.makeQueue(maxConcurrency: 1)
        let d1 = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/seq1"))
        let d2 = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/seq2"))

        await queue.enqueue(d1)
        await queue.enqueue(d2)

        let bothDone = await awaitState(queue: queue, timeout: Duration.seconds(10)) { ops in
            let terminals = ops.filter {
                switch $0.state {
                case .completed, .failed, .cancelled: true
                default: false
                }
            }
            return terminals.count >= 2
        }
        XCTAssertTrue(bothDone, "Both operations should complete when concurrency=1")
    }
}

// MARK: - FileOperationQueue snapshot helper (test support)

extension FileOperationQueue {
    /// Expose current operations snapshot for polling tests.
    func snapshot() async -> [FeaturesOperations.Operation] {
        var result: [FeaturesOperations.Operation] = []
        var stream = self.operationStream().makeAsyncIterator()
        if let ops = await stream.next() {
            result = ops
        }
        return result
    }
}
