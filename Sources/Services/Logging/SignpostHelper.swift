import OSLog

/// Async wrapper around `os_signpost` interval instrumentation.
/// Wraps any async throwing work in a named signpost interval visible in
/// Instruments' Time Profiler and the os_signpost instrument.
public enum SignpostHelper {
    private static let signposter = OSSignposter(
        subsystem: OSLogger.subsystem,
        category: "signpost"
    )

    /// Executes `work` wrapped in a named signpost interval.
    /// Errors from `work` are reraised without wrapping; the interval is
    /// always closed whether `work` succeeds or throws.
    @discardableResult
    public static func withSignpost<T: Sendable>(
        _ name: StaticString,
        _ work: @Sendable () async throws -> T
    ) async rethrows -> T {
        let state = Self.signposter.beginInterval(name)
        do {
            let result = try await work()
            Self.signposter.endInterval(name, state)
            return result
        } catch {
            Self.signposter.endInterval(name, state)
            throw error
        }
    }
}
