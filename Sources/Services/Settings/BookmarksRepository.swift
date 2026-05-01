import Core
import Foundation

/// Persists and observes the user's bookmark list.
///
/// Bookmarks are stored in `~/Library/Application Support/Stevedore/bookmarks.json`.
/// The in-memory cache is populated on first access; all subsequent reads are O(1).
public actor BookmarksRepository {
    private let store: JSONFileStore
    private var cache: [Bookmark]?
    private var continuations: [UUID: AsyncStream<[Bookmark]>.Continuation] = [:]

    public init(store: JSONFileStore) {
        self.store = store
    }

    public func all() async -> [Bookmark] {
        await self.loaded()
    }

    public func save(_ bookmarks: [Bookmark]) async throws {
        self.cache = bookmarks
        try await self.store.write(bookmarks)
        self.notifyContinuations(bookmarks)
    }

    /// Returns a stream that emits the current list on subscription and again
    /// after every `save(_:)` call.
    public nonisolated func observe() -> AsyncStream<[Bookmark]> {
        AsyncStream<[Bookmark]> { continuation in
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

    private func loaded() async -> [Bookmark] {
        if let cache { return cache }
        let items = await self.store.read([Bookmark].self) ?? []
        if self.cache == nil { self.cache = items }
        return self.cache ?? items
    }

    private func notifyContinuations(_ items: [Bookmark]) {
        for continuation in self.continuations.values {
            continuation.yield(items)
        }
    }

    private func storeContinuation(id: UUID, _ continuation: AsyncStream<[Bookmark]>.Continuation) {
        self.continuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        if let continuation = self.continuations.removeValue(forKey: id) {
            continuation.finish()
        }
    }
}
