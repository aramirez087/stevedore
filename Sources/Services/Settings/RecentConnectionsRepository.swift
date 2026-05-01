import Core
import Foundation

/// Persists and observes the user's recently-used remote connections.
///
/// Connections are stored in
/// `~/Library/Application Support/Stevedore/recent-connections.json`.
/// The list is capped at `maxCount` entries; duplicate IDs are collapsed when
/// prepending so a re-used server always floats to the top.
public actor RecentConnectionsRepository {
    public static let maxCount = 20

    private let store: JSONFileStore
    private var cache: [RemoteHostDescriptor]?
    private var continuations: [UUID: AsyncStream<[RemoteHostDescriptor]>.Continuation] = [:]

    public init(store: JSONFileStore) {
        self.store = store
    }

    public func all() async -> [RemoteHostDescriptor] {
        await self.loaded()
    }

    public func save(_ descriptors: [RemoteHostDescriptor]) async throws {
        self.cache = descriptors
        try await self.store.write(descriptors)
        self.notifyContinuations(descriptors)
    }

    /// Inserts `descriptor` at the front of the list, removes any existing
    /// entry with the same `id`, and trims the list to `maxCount`.
    public func prepend(_ descriptor: RemoteHostDescriptor) async throws {
        var items = await self.loaded()
        items.removeAll { $0.id == descriptor.id }
        items.insert(descriptor, at: 0)
        if items.count > Self.maxCount {
            items = Array(items.prefix(Self.maxCount))
        }
        try await self.save(items)
    }

    /// Returns a stream that emits the current list on subscription and again
    /// after every mutation.
    public nonisolated func observe() -> AsyncStream<[RemoteHostDescriptor]> {
        AsyncStream<[RemoteHostDescriptor]> { continuation in
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

    private func loaded() async -> [RemoteHostDescriptor] {
        if let cache { return cache }
        let items = await self.store.read([RemoteHostDescriptor].self) ?? []
        if self.cache == nil { self.cache = items }
        return self.cache ?? items
    }

    private func notifyContinuations(_ items: [RemoteHostDescriptor]) {
        for continuation in self.continuations.values {
            continuation.yield(items)
        }
    }

    private func storeContinuation(id: UUID, _ continuation: AsyncStream<[RemoteHostDescriptor]>.Continuation) {
        self.continuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        if let continuation = self.continuations.removeValue(forKey: id) {
            continuation.finish()
        }
    }
}
