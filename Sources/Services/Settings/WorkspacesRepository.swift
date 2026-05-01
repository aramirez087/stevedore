import Core
import Foundation

/// Persists and observes the user's workspace list.
///
/// Workspaces are stored in `~/Library/Application Support/Stevedore/workspaces.json`.
/// The in-memory cache is populated on first access; all subsequent reads are O(1).
public actor WorkspacesRepository {
    private let store: JSONFileStore
    private var cache: [Workspace]?
    private var continuations: [UUID: AsyncStream<[Workspace]>.Continuation] = [:]

    public init(store: JSONFileStore) {
        self.store = store
    }

    public func all() async -> [Workspace] {
        await self.loaded()
    }

    public func save(_ workspaces: [Workspace]) async throws {
        self.cache = workspaces
        try await self.store.write(workspaces)
        self.notifyContinuations(workspaces)
    }

    /// Returns a stream that emits the current list on subscription and again
    /// after every `save(_:)` call.
    public nonisolated func observe() -> AsyncStream<[Workspace]> {
        AsyncStream<[Workspace]> { continuation in
            let token = UUID()
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.storeContinuation(id: token, continuation)
                let current = await self.loaded()
                continuation.yield(current)
            }
            continuation.onTermination = { [weak self] _ in
                task.cancel()
                guard let self else { return }
                Task { await self.removeContinuation(id: token) }
            }
        }
    }

    private func loaded() async -> [Workspace] {
        if let cache { return cache }
        let items = await self.store.read([Workspace].self) ?? []
        if self.cache == nil { self.cache = items }
        return self.cache ?? items
    }

    private func notifyContinuations(_ items: [Workspace]) {
        for continuation in self.continuations.values {
            continuation.yield(items)
        }
    }

    private func storeContinuation(id: UUID, _ continuation: AsyncStream<[Workspace]>.Continuation) {
        self.continuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        if let continuation = self.continuations.removeValue(forKey: id) {
            continuation.finish()
        }
    }
}
