import Foundation

/// `SettingsStore` backed by an in-memory dictionary of JSON-encoded values.
///
/// Encoding through JSON keeps the in-memory shape isomorphic to the on-disk
/// shape used by the real settings store, so tests catch coding mistakes.
/// `observe` emits the current value once on subscription and again on each
/// `set`, and finishes when the store is reset.
public actor InMemorySettingsStore: SettingsStore {
    private var storage: [String: Data] = [:]
    private var continuations: [String: [UUID: AsyncStream<Data>.Continuation]] = [:]

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func value<Value: Codable & Sendable>(for setting: Setting<Value>) async -> Value {
        guard let data = storage[setting.key],
              let decoded = try? decoder.decode(Value.self, from: data)
        else {
            return setting.defaultValue
        }
        return decoded
    }

    public func set<Value: Codable & Sendable>(_ value: Value, for setting: Setting<Value>) async {
        guard let data = try? encoder.encode(value) else { return }
        self.storage[setting.key] = data
        let bucket = self.continuations[setting.key] ?? [:]
        for continuation in bucket.values {
            continuation.yield(data)
        }
    }

    public nonisolated func observe<Value: Codable & Sendable>(_ setting: Setting<Value>) -> AsyncStream<Value> {
        let key = setting.key
        let defaultValue = setting.defaultValue
        return AsyncStream<Value> { continuation in
            let token = UUID()
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                let dataStream = await self.registerObserver(key: key, token: token)
                if let initial = await self.snapshot(forKey: key) {
                    if let value = try? JSONDecoder().decode(Value.self, from: initial) {
                        continuation.yield(value)
                    }
                } else {
                    continuation.yield(defaultValue)
                }
                for await data in dataStream {
                    if let value = try? JSONDecoder().decode(Value.self, from: data) {
                        continuation.yield(value)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { [weak self] _ in
                task.cancel()
                guard let self else { return }
                Task { await self.removeObserver(key: key, token: token) }
            }
        }
    }

    private func snapshot(forKey key: String) -> Data? {
        self.storage[key]
    }

    private func registerObserver(key: String, token: UUID) -> AsyncStream<Data> {
        AsyncStream<Data> { continuation in
            var bucket = self.continuations[key] ?? [:]
            bucket[token] = continuation
            self.continuations[key] = bucket
        }
    }

    private func removeObserver(key: String, token: UUID) {
        guard var bucket = continuations[key] else { return }
        if let continuation = bucket.removeValue(forKey: token) {
            continuation.finish()
        }
        if bucket.isEmpty {
            self.continuations.removeValue(forKey: key)
        } else {
            self.continuations[key] = bucket
        }
    }

    /// Drops all stored values and finishes any active observers.
    public func reset() {
        for bucket in self.continuations.values {
            for continuation in bucket.values {
                continuation.finish()
            }
        }
        self.continuations.removeAll()
        self.storage.removeAll()
    }
}
