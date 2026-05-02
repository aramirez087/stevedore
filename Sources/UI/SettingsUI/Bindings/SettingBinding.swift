import Core
import Observation
import ServicesSettings
import SwiftUI

/// Bridges a `Setting<T>` to a SwiftUI `Binding<T>` by subscribing to the
/// store's `AsyncStream` and writing back immediately on set.
///
/// Create on `@MainActor` and hold as `@State` in a view. Call `start()` from
/// `.task {}` and `stop()` from `.onDisappear {}`.
@Observable
@MainActor
public final class SettingBinding<T: Codable & Sendable & Equatable> {
    public private(set) var value: T

    @ObservationIgnored
    private let setting: Setting<T>

    @ObservationIgnored
    private let store: any SettingsStore

    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    public init(setting: Setting<T>, store: any SettingsStore) {
        self.setting = setting
        self.store = store
        self.value = setting.defaultValue
    }

    /// Starts stream subscription. Call from `.task` modifier.
    public func start() {
        self.observationTask?.cancel()
        self.observationTask = Task { [weak self] in
            guard let self else { return }
            for await v in self.store.observe(self.setting) {
                guard !Task.isCancelled else { break }
                self.value = v
            }
        }
    }

    /// Cancels stream subscription. Call from `.onDisappear` modifier.
    public func stop() {
        self.observationTask?.cancel()
        self.observationTask = nil
    }

    /// SwiftUI `Binding<T>` that reads `value` and writes through to the store.
    public var binding: Binding<T> {
        Binding(
            get: { self.value },
            set: { [weak self] newValue in
                guard let self else { return }
                self.value = newValue
                Task { await self.store.set(newValue, for: self.setting) }
            }
        )
    }
}
