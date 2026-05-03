import Core
import UIConnectDialog
import XCTest

/// Verifies that test-connection failure messages never contain credential
/// material regardless of which error path fires.
@MainActor
final class ConnectDialogTestsRedaction: XCTestCase {

    private let secretPassword = "supersecret123!@#"
    private let secretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    private let username = "alice"

    // MARK: - Failure status messages (all non-success result codes)

    func testAllResultStatusesProduceRedactedMessages() async {
        let failStatuses: [ConnectionTestResult.Status] = [
            .authenticationFailed, .unreachable, .timeout, .unsupported, .unknown,
        ]

        for status in failStatuses {
            let connector = MockRemoteConnector()
            connector.testResult = ConnectionTestResult(status: status)
            let vm = makePasswordViewModel(connector: connector)

            await vm.testConnection()

            assertNoCredentials(in: vm.testStatus, context: "status=\(status)")
        }
    }

    // MARK: - Thrown error path

    func testThrownErrorContainingPasswordIsRedacted() async {
        let connector = MockRemoteConnector()
        connector.testError = RawError(message: "auth error: password=\(secretPassword)")
        let vm = makePasswordViewModel(connector: connector)

        await vm.testConnection()

        assertNoCredentials(in: vm.testStatus, context: "thrown error path")
    }

    func testThrownErrorContainingUsernameIsRedacted() async {
        let connector = MockRemoteConnector()
        connector.testError = RawError(message: "failed for user \(username)")
        let vm = makePasswordViewModel(connector: connector)

        await vm.testConnection()

        assertNoCredentials(in: vm.testStatus, context: "username in thrown error")
    }

    // MARK: - S3 secret key is never exposed

    func testS3SecretKeyNotInFailureMessage() async {
        let connector = MockRemoteConnector()
        connector.testResult = ConnectionTestResult(status: .authenticationFailed)
        let vm = makeS3ViewModel(connector: connector)

        await vm.testConnection()

        assertNoS3Secrets(in: vm.testStatus)
    }

    func testS3ThrownErrorIsRedacted() async {
        let connector = MockRemoteConnector()
        connector.testError = RawError(message: "request signed with key=\(secretKey)")
        let vm = makeS3ViewModel(connector: connector)

        await vm.testConnection()

        assertNoS3Secrets(in: vm.testStatus)
    }

    // MARK: - Helper assertions

    private func assertNoCredentials(
        in status: TestStatus,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let message) = status else { return }
        let secrets = [secretPassword, username]
        for secret in secrets {
            XCTAssertFalse(
                message.contains(secret),
                "[\(context)] Message '\(message)' must not contain '\(secret)'",
                file: file,
                line: line
            )
        }
    }

    private func assertNoS3Secrets(
        in status: TestStatus,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let message) = status else { return }
        let secrets = [secretKey, "AKIAIOSFODNN7EXAMPLE"]
        for secret in secrets {
            XCTAssertFalse(
                message.contains(secret),
                "S3 secret '\(secret)' must not appear in failure message: '\(message)'",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Helpers

    private func makePasswordViewModel(connector: MockRemoteConnector) -> ConnectDialogViewModel {
        let vm = ConnectDialogViewModel(
            credentialStore: InMemoryCredentialStore(),
            connector: connector
        )
        vm.scheme = .sftp
        vm.displayName = "Test"
        vm.host = "sftp.example.com"
        vm.username = username
        vm.password = secretPassword
        vm.authMode = .password
        return vm
    }

    private func makeS3ViewModel(connector: MockRemoteConnector) -> ConnectDialogViewModel {
        let vm = ConnectDialogViewModel(
            credentialStore: InMemoryCredentialStore(),
            connector: connector
        )
        vm.scheme = .s3
        vm.displayName = "My Bucket"
        vm.host = "s3.amazonaws.com"
        vm.authMode = .iam
        vm.s3AccessKeyID = "AKIAIOSFODNN7EXAMPLE"
        vm.s3SecretKey = secretKey
        vm.s3Bucket = "my-bucket"
        return vm
    }
}
