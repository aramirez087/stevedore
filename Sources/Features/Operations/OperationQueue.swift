import Core
import Foundation

/// Queue-driven engine that executes batched file operations with a configurable
/// concurrency cap.
///
/// Named `FileOperationQueue` (not `OperationQueue`) to avoid shadowing
/// `Foundation.OperationQueue` at import sites.
///
/// The queue is the single source of truth for operation state. Subscribers
/// receive `AsyncStream<[Operation]>` snapshots after every state change.
public actor FileOperationQueue {
    public let maxConcurrency: Int

    /// All operations, ordered by enqueue time. Mutated only by actor methods.
    private var operations: [Operation] = []
    /// Active task handles, keyed by operation ID.
    private var activeTasks: [Operation.ID: Task<OperationResult, any Error>] = [:]
    /// Pause/resume gate for each active operation.
    private var gates: [Operation.ID: PauseResumeGate] = [:]
    /// Snapshot subscribers.
    private var continuations: [UUID: AsyncStream<[Operation]>.Continuation] = [:]
    private let executor: OperationExecutor

    public init(executor: OperationExecutor, maxConcurrency: Int = 2) {
        self.executor = executor
        self.maxConcurrency = maxConcurrency
    }

    // MARK: - Public API

    /// Enqueue a descriptor; starts execution immediately if capacity allows.
    public func enqueue(_ descriptor: OperationDescriptor) {
        let operation = Operation(descriptor: descriptor)
        self.operations.append(operation)
        self.broadcast()
        self.drain()
    }

    /// Cancel a specific operation.
    public func cancel(_ id: Operation.ID) async {
        guard let idx = self.operations.firstIndex(where: { $0.id == id }) else { return }
        switch self.operations[idx].state {
        case .pending:
            self.operations[idx].state = .cancelled
            self.broadcast()
        case .active, .paused:
            self.activeTasks[id]?.cancel()
            // Wake the gate so the task can observe cancellation immediately.
            await self.gates[id]?.resume()
        default:
            break
        }
    }

    /// Pause an active operation at the next chunk boundary.
    public func pause(_ id: Operation.ID) async {
        guard let idx = self.operations.firstIndex(where: { $0.id == id }) else { return }
        guard case .active = self.operations[idx].state else { return }
        await self.gates[id]?.pause()
        self.operations[idx].state = .paused
        self.broadcast()
    }

    /// Resume a paused operation.
    public func resume(_ id: Operation.ID) async {
        guard let idx = self.operations.firstIndex(where: { $0.id == id }) else { return }
        guard case .paused = self.operations[idx].state else { return }
        await self.gates[id]?.resume()
        self.operations[idx].state = .active
        self.broadcast()
    }

    /// Cancel every operation in the queue.
    public func cancelAll() async {
        let ids = self.operations.map(\.id)
        for id in ids {
            await self.cancel(id)
        }
    }

    /// Subscribe to queue snapshots. The stream yields after every state change.
    public nonisolated func operationStream() -> AsyncStream<[Operation]> {
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

    // MARK: - Private

    private func drain() {
        let activeCount = self.activeTasks.count
        let available = self.maxConcurrency - activeCount
        guard available > 0 else { return }

        let pendingOps = self.operations.filter {
            if case .pending = $0.state { return true }
            return false
        }
        let toStart = min(available, pendingOps.count)
        guard toStart > 0 else { return }

        for i in 0 ..< toStart {
            let op = pendingOps[i]
            let opID = op.id
            guard let idx = self.operations.firstIndex(where: { $0.id == opID }) else { continue }

            let gate = PauseResumeGate()
            self.gates[opID] = gate
            self.operations[idx].state = .active

            // Capture a snapshot of the operation for the task.
            let snapshot = self.operations[idx]
            let task = Task { [executor = self.executor] in
                try await executor.execute(snapshot, gate: gate)
            }
            self.activeTasks[opID] = task
            self.broadcast()

            // Observe task completion without holding a reference to self via capture.
            Task {
                let result: Result<OperationResult, any Error>
                do {
                    let value = try await task.value
                    result = .success(value)
                } catch {
                    result = .failure(error)
                }
                await self.finish(opID, result: result)
            }
        }
    }

    private func finish(
        _ id: Operation.ID,
        result: Result<OperationResult, any Error>
    ) async {
        self.activeTasks.removeValue(forKey: id)
        self.gates.removeValue(forKey: id)
        await self.executor.progressTracker.complete(operationID: id)

        guard let idx = self.operations.firstIndex(where: { $0.id == id }) else { return }
        switch result {
        case .success(let r):
            if case .cancelled = r.status {
                self.operations[idx].state = .cancelled
            } else {
                self.operations[idx].state = .completed(r)
            }
        case .failure(let e):
            if (e as? CancellationError) != nil {
                self.operations[idx].state = .cancelled
            } else {
                self.operations[idx].state = .failed(e)
            }
        }
        self.broadcast()
        self.drain()
    }

    private func broadcast() {
        let snapshot = self.operations
        for continuation in self.continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func register(
        id: UUID,
        continuation: AsyncStream<[Operation]>.Continuation
    ) {
        self.continuations[id] = continuation
        continuation.yield(self.operations)
    }

    private func unregister(id: UUID) {
        self.continuations.removeValue(forKey: id)
    }
}
