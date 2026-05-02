import Foundation
import Observation

/// Closure type for the debounce sleep — injectable for deterministic tests.
public typealias SleepFunction = @Sendable (Duration) async throws -> Void

/// Debounces search input with a configurable interval and injectable clock.
///
/// Inject `sleep: { _ in }` in tests so tasks complete without real delay.
/// `onFire` receives only the latest term when the debounce window elapses.
@MainActor
@Observable
public final class SearchDebouncer {
    public private(set) var term: String = ""
    public var onFire: ((String) -> Void)?

    private let interval: Duration
    private let sleep: SleepFunction
    private var pendingTask: Task<Void, Never>?

    public init(
        interval: Duration = .milliseconds(250),
        sleep: @escaping SleepFunction = { try await Task.sleep(for: $0) }
    ) {
        self.interval = interval
        self.sleep = sleep
    }

    /// Update the current search term and restart the debounce window.
    public func update(_ newTerm: String) {
        self.term = newTerm
        self.pendingTask?.cancel()
        let snapshot = newTerm
        let sleepFn = self.sleep
        let fireInterval = self.interval
        self.pendingTask = Task { [weak self] in
            try? await sleepFn(fireInterval)
            guard !Task.isCancelled, let self else { return }
            self.onFire?(snapshot)
        }
    }

    /// Cancel any pending fire, reset the term, and immediately emit an empty string.
    public func clear() {
        self.pendingTask?.cancel()
        self.pendingTask = nil
        self.term = ""
        self.onFire?("")
    }
}
