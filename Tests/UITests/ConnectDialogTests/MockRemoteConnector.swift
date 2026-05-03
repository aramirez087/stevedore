import Core
import Foundation

/// Test double for `RemoteConnector`. Configure `testResult` or `testError` before each test.
final class MockRemoteConnector: RemoteConnector, @unchecked Sendable {
    var testResult: ConnectionTestResult = ConnectionTestResult(status: .success, latencyMilliseconds: 42)
    var testError: (any Error)?
    var testCallCount: Int = 0
    var lastTestedHost: RemoteHostDescriptor?
    var lastTestedCredential: Credential?

    func test(
        _ host: RemoteHostDescriptor,
        credential: Credential?
    ) async throws -> ConnectionTestResult {
        testCallCount += 1
        lastTestedHost = host
        lastTestedCredential = credential
        if let testError { throw testError }
        return testResult
    }

    func open(
        _ host: RemoteHostDescriptor,
        credential: Credential?
    ) async throws -> any FileSystemProvider {
        fatalError("MockRemoteConnector.open is not expected in unit tests")
    }
}

/// A minimal `Error` carrying a raw message — used to verify sanitization.
struct RawError: Error {
    let message: String
}
