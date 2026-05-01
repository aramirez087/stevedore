import Core
import Foundation

// MARK: - TransferProgress

/// Per-operation progress snapshot emitted by `TransferProgressTracker`.
public struct TransferProgress: Sendable {
    public let operationID: OperationDescriptor.ID
    public var bytesCompleted: Int64
    public var bytesTotal: Int64?
    public var itemsCompleted: Int
    public var itemsTotal: Int
    public var throughputBytesPerSecond: Int64?
    public var estimatedSecondsRemaining: Double?

    /// Fractional completion in `[0, 1]`, or `nil` when total is unknown or zero.
    public var fraction: Double? {
        guard let total = self.bytesTotal, total > 0 else { return nil }
        return min(1.0, Double(self.bytesCompleted) / Double(total))
    }

    public init(operationID: OperationDescriptor.ID) {
        self.operationID = operationID
        self.bytesCompleted = 0
        self.bytesTotal = nil
        self.itemsCompleted = 0
        self.itemsTotal = 0
        self.throughputBytesPerSecond = nil
        self.estimatedSecondsRemaining = nil
    }
}

// MARK: - QueueProgress

/// Aggregate progress across all active operations in the queue.
public struct QueueProgress: Sendable {
    public let perOperation: [OperationDescriptor.ID: TransferProgress]

    public init(perOperation: [OperationDescriptor.ID: TransferProgress]) {
        self.perOperation = perOperation
    }

    /// Sum of `bytesCompleted` across all operations.
    public var aggregateBytesCompleted: Int64 {
        self.perOperation.values.map(\.bytesCompleted).reduce(0, +)
    }

    /// Sum of `bytesTotal` across all operations, or `nil` if any op has an unknown total.
    public var aggregateBytesTotal: Int64? {
        var total: Int64 = 0
        for op in self.perOperation.values {
            guard let t = op.bytesTotal else { return nil }
            total += t
        }
        return total
    }
}

// MARK: - TransferProgressTracker

/// Actor that receives per-operation progress updates and broadcasts throttled
/// `QueueProgress` snapshots to subscribers at ≤10 Hz.
///
/// `complete(operationID:)` always emits immediately, bypassing the throttle,
/// so the UI always receives the final 100% update.
public actor TransferProgressTracker {
    private let minReportInterval: Duration
    private var lastReport: ContinuousClock.Instant?
    private var current: [OperationDescriptor.ID: TransferProgress] = [:]
    private var continuations: [UUID: AsyncStream<QueueProgress>.Continuation] = [:]

    public init(minReportInterval: Duration = .milliseconds(100)) {
        self.minReportInterval = minReportInterval
    }

    /// Update progress for an operation. Throttled to `minReportInterval`.
    public func update(_ progress: TransferProgress) async {
        self.current[progress.operationID] = progress
        let now = ContinuousClock.now
        if let last = self.lastReport, now - last < self.minReportInterval {
            return
        }
        self.emit(at: now)
    }

    /// Mark an operation complete and always emit — bypasses the throttle.
    public func complete(operationID: OperationDescriptor.ID) async {
        self.current.removeValue(forKey: operationID)
        self.emit(at: ContinuousClock.now)
    }

    /// Subscribe to queue progress updates.
    public nonisolated func progressStream() -> AsyncStream<QueueProgress> {
        AsyncStream { continuation in
            let id = UUID()
            Task {
                await self.register(id: id, continuation: continuation)
                continuation.onTermination = { [id] _ in
                    Task { await self.unregister(id: id) }
                }
            }
        }
    }

    // MARK: Private

    private func register(
        id: UUID,
        continuation: AsyncStream<QueueProgress>.Continuation
    ) {
        self.continuations[id] = continuation
        // Immediately emit the current snapshot to the new subscriber.
        continuation.yield(QueueProgress(perOperation: self.current))
    }

    private func unregister(id: UUID) {
        self.continuations.removeValue(forKey: id)
    }

    private func emit(at instant: ContinuousClock.Instant) {
        self.lastReport = instant
        let snapshot = QueueProgress(perOperation: self.current)
        for continuation in self.continuations.values {
            continuation.yield(snapshot)
        }
    }
}
