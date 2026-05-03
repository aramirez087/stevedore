import Core
import Foundation

/// Exponential backoff policy for transport reconnections.
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let baseDelayNanoseconds: UInt64
    public let maxDelayNanoseconds: UInt64
    public let jitterFraction: Double

    public init(
        maxAttempts: Int = 3,
        baseDelayNanoseconds: UInt64 = 1_000_000_000,
        maxDelayNanoseconds: UInt64 = 30_000_000_000,
        jitterFraction: Double = 0.25
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelayNanoseconds = baseDelayNanoseconds
        self.maxDelayNanoseconds = maxDelayNanoseconds
        self.jitterFraction = jitterFraction
    }

    public static let `default` = Self()

    /// Delay in nanoseconds for a given attempt index (0-based).
    /// Formula: min(maxDelay, base * 2^attempt) * (1 + jitter in [-fraction, +fraction]).
    public func delay(forAttempt attempt: Int) -> UInt64 {
        let shift = min(attempt, 62)
        let raw = Double(baseDelayNanoseconds) * pow(2.0, Double(shift))
        let capped = min(raw, Double(maxDelayNanoseconds))
        let jitter = Double.random(in: (1.0 - self.jitterFraction) ... (1.0 + self.jitterFraction))
        return UInt64(max(0, capped * jitter))
    }
}

/// Manages the lifecycle of a remote transport: creation, reconnect, idle-timeout
/// disconnect, and cancellation propagation.
///
/// All operations are funnelled through `withTransport` which ensures the
/// transport is alive, resets the idle timer, and executes the caller's body
/// on the underlying connection.
public actor RemoteSession<Transport: Sendable> {
    private let factory: @Sendable () async throws -> Transport
    private let retryPolicy: RetryPolicy
    private let idleTimeoutNanoseconds: UInt64
    private var transport: Transport?
    private var idleTimeoutTask: Task<Void, Never>?

    public init(
        factory: @escaping @Sendable () async throws -> Transport,
        retryPolicy: RetryPolicy = .default,
        idleTimeoutNanoseconds: UInt64 = 60_000_000_000
    ) {
        self.factory = factory
        self.retryPolicy = retryPolicy
        self.idleTimeoutNanoseconds = idleTimeoutNanoseconds
    }

    /// Obtain a transport, execute `body`, and return the result.
    /// Reconnects with exponential backoff if the transport is absent.
    /// Propagates `CancellationError` immediately (no retry).
    public func withTransport<R: Sendable>(
        _ body: @Sendable (Transport) async throws -> R
    ) async throws -> R {
        try Task.checkCancellation()
        let t = try await ensureTransport()
        self.resetIdleTimeout()
        do {
            return try await body(t)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as StevedoreError {
            if case .remote = error {
                transport = nil
            }
            throw error
        }
    }

    /// Immediately disconnect the transport (cancels idle timer).
    public func disconnect() {
        self.idleTimeoutTask?.cancel()
        self.idleTimeoutTask = nil
        self.transport = nil
    }

    // MARK: - Private helpers

    private func ensureTransport() async throws -> Transport {
        if let existing = transport {
            return existing
        }
        return try await self.connectWithRetry()
    }

    private func connectWithRetry() async throws -> Transport {
        var lastError: any Error = StevedoreError.remote(.connectionFailed(detail: "unknown"))
        for attempt in 0 ..< self.retryPolicy.maxAttempts {
            try Task.checkCancellation()
            do {
                let t = try await factory()
                self.transport = t
                return t
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt < self.retryPolicy.maxAttempts - 1 {
                    let delay = self.retryPolicy.delay(forAttempt: attempt)
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }
        throw lastError
    }

    private func resetIdleTimeout() {
        self.idleTimeoutTask?.cancel()
        let ns = self.idleTimeoutNanoseconds
        self.idleTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: ns)
            await self?.disconnect()
        }
    }
}
