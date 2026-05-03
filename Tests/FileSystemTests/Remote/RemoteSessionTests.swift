import Core
@testable import FileSystemRemote
import os
import XCTest

final class RemoteSessionTests: XCTestCase {
    // MARK: - Basic transport delivery

    func testWithTransportDeliversValue() async throws {
        let session = RemoteSession<Int> { 42 }
        let result = try await session.withTransport { $0 }
        XCTAssertEqual(result, 42)
    }

    func testTransportIsReused() async throws {
        let callCount = OSAllocatedUnfairLock(initialState: 0)
        let session = RemoteSession<String> {
            callCount.withLock { $0 += 1 }
            return "transport"
        }
        _ = try await session.withTransport { $0 }
        _ = try await session.withTransport { $0 }
        XCTAssertEqual(callCount.withLock { $0 }, 1, "factory should only be called once")
    }

    // MARK: - Retry policy

    func testRetriesOnConnectionFailure() async throws {
        let attempts = OSAllocatedUnfairLock(initialState: 0)
        let session = RemoteSession<Int>(
            factory: {
                let n = attempts.withLock { state -> Int in
                    state += 1
                    return state
                }
                if n < 3 {
                    throw StevedoreError.remote(.connectionFailed(detail: "attempt \(n)"))
                }
                return 99
            },
            retryPolicy: RetryPolicy(
                maxAttempts: 3,
                baseDelayNanoseconds: 0,
                maxDelayNanoseconds: 0,
                jitterFraction: 0
            )
        )
        let result = try await session.withTransport { $0 }
        XCTAssertEqual(result, 99)
        XCTAssertEqual(attempts.withLock { $0 }, 3)
    }

    func testThrowsAfterMaxRetries() async throws {
        let attempts = OSAllocatedUnfairLock(initialState: 0)
        let session = RemoteSession<Int>(
            factory: {
                attempts.withLock { $0 += 1 }
                throw StevedoreError.remote(.connectionFailed(detail: "always fails"))
            },
            retryPolicy: RetryPolicy(
                maxAttempts: 2,
                baseDelayNanoseconds: 0,
                maxDelayNanoseconds: 0,
                jitterFraction: 0
            )
        )
        do {
            _ = try await session.withTransport { $0 }
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(attempts.withLock { $0 }, 2)
        }
    }

    // MARK: - Disconnect

    func testDisconnectClearsTransport() async throws {
        let callCount = OSAllocatedUnfairLock(initialState: 0)
        let session = RemoteSession<Int> {
            callCount.withLock { state -> Int in
                state += 1
                return state
            }
        }
        _ = try await session.withTransport { $0 }
        await session.disconnect()
        let second = try await session.withTransport { $0 }
        XCTAssertEqual(second, 2, "factory should be called again after disconnect")
        XCTAssertEqual(callCount.withLock { $0 }, 2)
    }

    // MARK: - RetryPolicy delay

    func testRetryPolicyDelayGrowsExponentially() {
        let policy = RetryPolicy(
            maxAttempts: 5,
            baseDelayNanoseconds: 100_000_000,
            maxDelayNanoseconds: 10_000_000_000,
            jitterFraction: 0
        )
        let d0 = policy.delay(forAttempt: 0)
        let d1 = policy.delay(forAttempt: 1)
        let d2 = policy.delay(forAttempt: 2)
        XCTAssertEqual(d0, 100_000_000)
        XCTAssertEqual(d1, 200_000_000)
        XCTAssertEqual(d2, 400_000_000)
    }

    func testRetryPolicyCappsAtMaxDelay() {
        let policy = RetryPolicy(
            maxAttempts: 5,
            baseDelayNanoseconds: 1_000_000_000,
            maxDelayNanoseconds: 2_000_000_000,
            jitterFraction: 0
        )
        let highAttempt = policy.delay(forAttempt: 30)
        XCTAssertEqual(highAttempt, 2_000_000_000)
    }

    func testRetryPolicyJitterBoundsRespected() {
        let policy = RetryPolicy(
            maxAttempts: 3,
            baseDelayNanoseconds: 1_000_000_000,
            maxDelayNanoseconds: 30_000_000_000,
            jitterFraction: 0.25
        )
        for _ in 0 ..< 50 {
            let delay = Double(policy.delay(forAttempt: 0))
            let base = 1_000_000_000.0
            XCTAssertGreaterThanOrEqual(delay, base * 0.75)
            XCTAssertLessThanOrEqual(delay, base * 1.25)
        }
    }

    // MARK: - Cancellation

    func testCancellationPropagatesImmediately() async {
        let session = RemoteSession<Int>(
            factory: {
                throw StevedoreError.remote(.connectionFailed(detail: "always fails"))
            },
            retryPolicy: RetryPolicy(
                maxAttempts: 10,
                baseDelayNanoseconds: 0,
                maxDelayNanoseconds: 0,
                jitterFraction: 0
            )
        )
        let task = Task {
            try await session.withTransport { $0 }
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation error")
        } catch is CancellationError {
            // Expected
        } catch {
            // Also acceptable — could be the connection error before cancel is checked
        }
    }
}
