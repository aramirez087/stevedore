import Core
import Foundation

// MARK: - SyncConflictResolution

/// The outcome of a manual conflict resolution decision.
public enum SyncConflictResolution: Sendable, Equatable {
    case keepLeft
    case keepRight
    case skip
}

// MARK: - SyncFileExecutor

/// Collaborator that physically executes copy and delete operations for the sync engine.
///
/// In production this is wired to `FeaturesOperations.FileOperationQueue` at the UI layer.
/// Tests supply a lightweight recording fake.
public protocol SyncFileExecutor: Sendable {
    func copy(
        from source: FilePath,
        on sourceProvider: any FileSystemProvider,
        to destination: FilePath,
        on destinationProvider: any FileSystemProvider
    ) async throws

    func delete(at path: FilePath, on provider: any FileSystemProvider) async throws
}

// MARK: - SyncEngine

/// Actor that executes a `SyncPlan` against two providers.
///
/// Suspends on `.conflict` steps when `ConflictResolutionStrategy == .manual`,
/// awaiting `resolveConflict(at:with:)` from the UI layer.
public actor SyncEngine {
    private let leftProvider: any FileSystemProvider
    private let rightProvider: any FileSystemProvider
    private let executor: any SyncFileExecutor
    public let progressTracker: SyncProgressTracker
    private var pendingConflicts: [FilePath: CheckedContinuation<SyncConflictResolution, Never>] = [:]

    public init(
        leftProvider: any FileSystemProvider,
        rightProvider: any FileSystemProvider,
        executor: any SyncFileExecutor,
        progressTracker: SyncProgressTracker = SyncProgressTracker()
    ) {
        self.leftProvider = leftProvider
        self.rightProvider = rightProvider
        self.executor = executor
        self.progressTracker = progressTracker
    }

    /// Execute a plan. Returns when all steps complete or an error is thrown.
    ///
    /// `leftRoot` and `rightRoot` are used to resolve absolute paths from each step's
    /// `relativePath` components.
    public func execute(plan: SyncPlan, leftRoot: FilePath, rightRoot: FilePath) async throws {
        await self.progressTracker.setTotal(rowsCompared: plan.steps.count)
        for step in plan.steps {
            try await self.executeStep(step, leftRoot: leftRoot, rightRoot: rightRoot)
            await self.progressTracker.stepCompleted()
        }
    }

    /// Unblock a suspended conflict step. No-op if `relativePath` is not waiting.
    public func resolveConflict(at relativePath: FilePath, with resolution: SyncConflictResolution) {
        guard let continuation = self.pendingConflicts.removeValue(forKey: relativePath) else {
            return
        }
        continuation.resume(returning: resolution)
    }

    // MARK: Private

    private func executeStep(_ step: SyncStep, leftRoot: FilePath, rightRoot: FilePath) async throws {
        switch step {
        case .copyToRight(let relativePath, let left):
            let dest = rightRoot.appending(relativePath.components)
            try await self.executor.copy(
                from: left.path,
                on: self.leftProvider,
                to: dest,
                on: self.rightProvider
            )

        case .copyToLeft(let relativePath, let right):
            let dest = leftRoot.appending(relativePath.components)
            try await self.executor.copy(
                from: right.path,
                on: self.rightProvider,
                to: dest,
                on: self.leftProvider
            )

        case .deleteFromRight(let relativePath):
            let path = rightRoot.appending(relativePath.components)
            try await self.executor.delete(at: path, on: self.rightProvider)

        case .deleteFromLeft(let relativePath):
            let path = leftRoot.appending(relativePath.components)
            try await self.executor.delete(at: path, on: self.leftProvider)

        case .replaceRight(let relativePath, let left):
            let dest = rightRoot.appending(relativePath.components)
            try await self.executor.copy(
                from: left.path,
                on: self.leftProvider,
                to: dest,
                on: self.rightProvider
            )

        case .replaceLeft(let relativePath, let right):
            let dest = leftRoot.appending(relativePath.components)
            try await self.executor.copy(
                from: right.path,
                on: self.rightProvider,
                to: dest,
                on: self.leftProvider
            )

        case .conflict(let relativePath, let left, let right):
            let resolution = await withCheckedContinuation { [relativePath] continuation in
                self.pendingConflicts[relativePath] = continuation
            }
            switch resolution {
            case .keepLeft:
                let dest = rightRoot.appending(relativePath.components)
                try await self.executor.copy(
                    from: left.path,
                    on: self.leftProvider,
                    to: dest,
                    on: self.rightProvider
                )
            case .keepRight:
                let dest = leftRoot.appending(relativePath.components)
                try await self.executor.copy(
                    from: right.path,
                    on: self.rightProvider,
                    to: dest,
                    on: self.leftProvider
                )
            case .skip:
                break
            }
        }
    }
}
