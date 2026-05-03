import Foundation

/// Sliding-window bytes-per-second estimator for transfer ETA display.
///
/// Not thread-safe — must only be mutated from a single isolation domain
/// (e.g., inside a single `Task` or actor). Value-type semantics ensure
/// copies are independent.
public struct ThroughputEstimator: Sendable {
    public let windowDuration: Duration

    private var samples: [(instant: ContinuousClock.Instant, bytes: Int64)]

    public init(windowDuration: Duration = .seconds(5)) {
        self.windowDuration = windowDuration
        self.samples = []
    }

    /// Record that `bytes` bytes were transferred at the current instant.
    public mutating func record(bytes: Int64) {
        let now = ContinuousClock.now
        let cutoff = now - self.windowDuration
        self.samples.removeAll { $0.instant < cutoff }
        self.samples.append((instant: now, bytes: bytes))
    }

    /// Current sliding-window estimate in bytes per second.
    ///
    /// Returns `nil` when fewer than two samples are in the window (cannot
    /// compute a meaningful rate from a single point in time).
    public var bytesPerSecond: Int64? {
        guard self.samples.count >= 2,
              let first = self.samples.first,
              let last = self.samples.last else { return nil }
        let windowSeconds = self.elapsedSeconds(from: first.instant, to: last.instant)
        guard windowSeconds > 0 else { return nil }
        let totalBytes = self.samples.map(\.bytes).reduce(0, +)
        return Int64(Double(totalBytes) / windowSeconds)
    }

    /// Estimated seconds remaining to transfer `bytesLeft` at current rate.
    public func estimatedSecondsRemaining(bytesLeft: Int64) -> Double? {
        guard bytesLeft > 0 else { return 0 }
        guard self.samples.count >= 2,
              let first = self.samples.first,
              let last = self.samples.last else { return nil }
        let windowSeconds = self.elapsedSeconds(from: first.instant, to: last.instant)
        guard windowSeconds > 0 else { return nil }
        let totalBytes = self.samples.map(\.bytes).reduce(0, +)
        let rate = Double(totalBytes) / windowSeconds
        guard rate > 0 else { return nil }
        return Double(bytesLeft) / rate
    }

    private func elapsedSeconds(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant
    ) -> Double {
        let d = start.duration(to: end)
        return Double(d.components.seconds) + Double(d.components.attoseconds) * 1e-18
    }
}
