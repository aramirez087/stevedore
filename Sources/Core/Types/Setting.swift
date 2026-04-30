/// Type-safe key for a value stored in `SettingsStore`.
///
/// Generic over `Value` so reads return concrete types without casting.
/// Equatable / Hashable on `key`; the default value is metadata, not part of
/// identity.
public struct Setting<Value: Codable & Sendable>: Sendable {
    public let key: String
    public let defaultValue: Value

    public init(key: String, defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
    }
}

extension Setting: Equatable {
    public static func == (lhs: Setting<Value>, rhs: Setting<Value>) -> Bool {
        lhs.key == rhs.key
    }
}

extension Setting: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.key)
    }
}
