import Core
import Foundation

/// `SettingsStore` backed by `UserDefaults`.
///
/// Every `Setting<Value>` is JSON-encoded and stored as `Data` under its key.
/// This keeps the encode/decode path isomorphic to `InMemorySettingsStore` and
/// avoids a type-dispatch matrix for Bool/Int/String/Double primitives.
///
/// Pass a custom `UserDefaults` suite via `init(defaults:)` to isolate tests:
/// ```swift
/// let suite = UserDefaults(suiteName: UUID().uuidString)!
/// let store = UserDefaultsSettingsStore(defaults: suite)
/// ```
public actor UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var continuations: [String: [UUID: AsyncStream<Data>.Continuation]] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func value<Value: Codable & Sendable>(for setting: Setting<Value>) async -> Value {
        guard
            let data = self.defaults.data(forKey: setting.key),
            let decoded = try? self.decoder.decode(Value.self, from: data)
        else {
            return setting.defaultValue
        }
        return decoded
    }

    public func set<Value: Codable & Sendable>(_ value: Value, for setting: Setting<Value>) async {
        guard let data = try? self.encoder.encode(value) else { return }
        self.defaults.set(data, forKey: setting.key)
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
        self.defaults.data(forKey: key)
    }

    private func registerObserver(key: String, token: UUID) -> AsyncStream<Data> {
        AsyncStream<Data> { continuation in
            var bucket = self.continuations[key] ?? [:]
            bucket[token] = continuation
            self.continuations[key] = bucket
        }
    }

    private func removeObserver(key: String, token: UUID) {
        guard var bucket = self.continuations[key] else { return }
        if let continuation = bucket.removeValue(forKey: token) {
            continuation.finish()
        }
        if bucket.isEmpty {
            self.continuations.removeValue(forKey: key)
        } else {
            self.continuations[key] = bucket
        }
    }
}
