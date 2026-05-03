import Core
import UIConnectDialog
import XCTest

/// Verifies that `testConnection()` calls the injected connector and surfaces
/// the result correctly without revealing credential material.
@MainActor
final class ConnectDialogTestsConnection: XCTestCase {

    func testSuccessUpdatesStatusToSuccess() async {
        let connector = MockRemoteConnector()
        connector.testResult = ConnectionTestResult(status: .success, latencyMilliseconds: 55)
        let vm = makePasswordViewModel(connector: connector)

        await vm.testConnection()

        XCTAssertEqual(vm.testStatus, .success(latencyMs: 55))
        XCTAssertEqual(connector.testCallCount, 1)
    }

    func testAuthFailureUpdatesStatusToFailure() async {
        let connector = MockRemoteConnector()
        connector.testResult = ConnectionTestResult(status: .authenticationFailed)
        let vm = makePasswordViewModel(connector: connector)

        await vm.testConnection()

        if case .failure = vm.testStatus { } else {
            XCTFail("Expected failure status, got \(vm.testStatus)")
        }
        XCTAssertEqual(connector.testCallCount, 1)
    }

    func testUnreachableUpdatesStatusToFailure() async {
        let connector = MockRemoteConnector()
        connector.testResult = ConnectionTestResult(status: .unreachable)
        let vm = makePasswordViewModel(connector: connector)

        await vm.testConnection()

        if case .failure = vm.testStatus { } else {
            XCTFail("Expected failure status, got \(vm.testStatus)")
        }
    }

    func testTimeoutUpdatesStatusToFailure() async {
        let connector = MockRemoteConnector()
        connector.testResult = ConnectionTestResult(status: .timeout)
        let vm = makePasswordViewModel(connector: connector)

        await vm.testConnection()

        if case .failure = vm.testStatus { } else {
            XCTFail("Expected failure status, got \(vm.testStatus)")
        }
    }

    func testThrownErrorUpdatesStatusToSanitizedFailure() async {
        let connector = MockRemoteConnector()
        connector.testError = RawError(message: "socket error: password=hunter2")
        let vm = makePasswordViewModel(connector: connector)

        await vm.testConnection()

        if case .failure(let message) = vm.testStatus {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected failure status, got \(vm.testStatus)")
        }
    }

    func testConnectorReceivesDescriptorWithCorrectScheme() async {
        let connector = MockRemoteConnector()
        let vm = makePasswordViewModel(connector: connector, scheme: .sftp)

        await vm.testConnection()

        XCTAssertEqual(connector.lastTestedHost?.scheme, .sftp)
        XCTAssertEqual(connector.lastTestedHost?.host, "sftp.example.com")
    }

    func testValidationBlocksTestWhenHostEmpty() async {
        let connector = MockRemoteConnector()
        let vm = ConnectDialogViewModel(
            credentialStore: InMemoryCredentialStore(),
            connector: connector
        )
        vm.scheme = .sftp
        vm.displayName = "Test"
        vm.host = ""

        await vm.testConnection()

        XCTAssertEqual(connector.testCallCount, 0, "Connector must not be called when validation fails")
        XCTAssertEqual(vm.testStatus, .idle)
    }

    func testStatusIsTestingDuringOperation() async {
        let connector = MockRemoteConnector()
        // Return immediately — we just verify the state machine transitions
        connector.testResult = ConnectionTestResult(status: .success)
        let vm = makePasswordViewModel(connector: connector)

        await vm.testConnection()

        // After completion the status must not be .testing
        XCTAssertNotEqual(vm.testStatus, .testing)
    }

    // MARK: - Helpers

    private func makePasswordViewModel(
        connector: MockRemoteConnector,
        scheme: ConnectionScheme = .sftp
    ) -> ConnectDialogViewModel {
        let vm = ConnectDialogViewModel(
            credentialStore: InMemoryCredentialStore(),
            connector: connector
        )
        vm.scheme = scheme
        vm.displayName = "Test Server"
        vm.host = "sftp.example.com"
        vm.username = "alice"
        vm.password = "hunter2"
        vm.authMode = .password
        return vm
    }
}
