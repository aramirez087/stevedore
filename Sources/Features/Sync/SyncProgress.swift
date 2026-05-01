import Foundation

// MARK: - SyncProgress

/// A progress snapshot for a sync operation.
public struct SyncProgress: Sendable, Equatable {
    /// Total differences found by the comparator.
    public let rowsCompared: Int
    /// Steps not yet started.
    public let rowsPending: Int
    /// Steps completed (success or skip).
    public let rowsDone: Int

    public var fraction: Double? {
        guard self.rowsCompared > 0 else { return nil }
        return min(1.0, Double(self.rowsDone) / Double(self.rowsCompared))
    }

    public init(rowsCompared: Int, rowsPending: Int, rowsDone: Int) {
        self.rowsCompared = rowsCompared
        self.rowsPending = rowsPending
        self.rowsDone = rowsDone
    }
}

// MARK: - SyncProgressTracker

/// Actor that collects sync step progress and broadcasts snapshots to subscribers.
public actor SyncProgressTracker {
    public private(set) var current: SyncProgress
    private var continuations: [UUID: AsyncStream<SyncProgress>.Continuation] = [:]
    private var totalRows: Int = 0
    private var pendingRows: Int = 0
    private var doneRows: Int = 0

    public init() {
        self.current = SyncProgress(rowsCompared: 0, rowsPending: 0, rowsDone: 0)
    }

    public func setTotal(rowsCompared: Int) {
        self.totalRows = rowsCompared
        self.pendingRows = rowsCompared
        self.doneRows = 0
        self.emitCurrent()
    }

    public func stepStarted() {
        // Reserved for future per-step start reporting.
    }

    public func stepCompleted() {
        self.doneRows += 1
        if self.pendingRows > 0 {
            self.pendingRows -= 1
        }
        self.emitCurrent()
    }

    /// Subscribe to sync progress updates. Immediately emits the current snapshot.
    public nonisolated func progressStream() -> AsyncStream<SyncProgress> {
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

    private func register(id: UUID, continuation: AsyncStream<SyncProgress>.Continuation) {
        self.continuations[id] = continuation
        continuation.yield(self.current)
    }

    private func unregister(id: UUID) {
        self.continuations.removeValue(forKey: id)
    }

    private func emitCurrent() {
        self.current = SyncProgress(
            rowsCompared: self.totalRows,
            rowsPending: self.pendingRows,
            rowsDone: self.doneRows
        )
        for continuation in self.continuations.values {
            continuation.yield(self.current)
        }
    }
}
