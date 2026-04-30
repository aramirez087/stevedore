/// Typed settings facade.
///
/// Generic over a `Setting<Value>` so callers retrieve concrete types without
/// casting. Observation is exposed via `AsyncStream` to compose with
/// SwiftUI's `.task` / `for await` consumers.
public protocol SettingsStore: Sendable {
    func value<Value: Codable & Sendable>(for setting: Setting<Value>) async -> Value
    func set<Value: Codable & Sendable>(_ value: Value, for setting: Setting<Value>) async
    func observe<Value: Codable & Sendable>(_ setting: Setting<Value>) -> AsyncStream<Value>
}
