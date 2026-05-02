import Core
@testable import UIConnectDialog
import XCTest

@MainActor
final class ConnectDialogTestConnectionTests: XCTestCase {
    func testStatusTransitionsIdleToTestingToSuccess() async {
        let connector = FakeRemoteConnector()
        await connector.setResult(.init(status: .success, latencyMilliseconds: 50))
        let vm = makeViewModel(scheme: .sftp, connector: connector)
        vm.hostname = "example.com"
        vm.username = "alice"

        XCTAssertEqual(vm.testStatus, .idle)
        await vm.testConnection()
        if case .success(let ms) = vm.testStatus {
            XCTAssertEqual(ms, 50)
        } else {
            XCTFail("Expected .success, got \(vm.testStatus)")
        }
    }

    func testConnectorReceivesDescriptorMatchingFormFields() async {
        let connector = FakeRemoteConnector()
        let vm = makeViewModel(scheme: .sftp, connector: connector)
        vm.hostname = "sftp.host.com"
        vm.username = "carol"

        await vm.testConnection()

        let calls = await connector.testCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].descriptor.host, "sftp.host.com")
        XCTAssertEqual(calls[0].descriptor.scheme, .sftp)
    }

    func testAuthFailedResultMapsToFailureStatus() async {
        let connector = FakeRemoteConnector()
        await connector.setResult(.init(status: .authenticationFailed))
        let vm = makeViewModel(scheme: .sftp, connector: connector)
        vm.hostname = "example.com"
        vm.username = "alice"

        await vm.testConnection()

        if case .failure(let msg) = vm.testStatus {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("Expected .failure, got \(vm.testStatus)")
        }
    }

    func testThrownErrorMapsToFailureStatus() async {
        let connector = FakeRemoteConnector()
        await connector.setShouldThrow(true)
        let vm = makeViewModel(scheme: .sftp, connector: connector)
        vm.hostname = "example.com"
        vm.username = "alice"

        await vm.testConnection()

        if case .failure = vm.testStatus {
            // expected
        } else {
            XCTFail("Expected .failure, got \(vm.testStatus)")
        }
    }

    func testAnonymousFTPCredentialIsNilForTestConnection() async {
        let connector = FakeRemoteConnector()
        let vm = makeViewModel(scheme: .ftp, connector: connector)
        vm.hostname = "ftp.example.com"
        vm.authMode = .anonymous

        await vm.testConnection()

        let calls = await connector.testCalls
        XCTAssertNil(calls[0].credential)
    }

    func testIAMS3CredentialIsNilForTestConnection() async {
        let connector = FakeRemoteConnector()
        let vm = makeViewModel(scheme: .s3, connector: connector)
        vm.s3Bucket = "bucket"
        vm.s3Region = "us-east-1"
        vm.authMode = .iam

        await vm.testConnection()

        let calls = await connector.testCalls
        XCTAssertNil(calls[0].credential)
    }
}

// MARK: - FakeRemoteConnector mutation helpers (actor-safe)

extension FakeRemoteConnector {
    func setResult(_ result: ConnectionTestResult) {
        testResultToReturn = result
    }

    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }
}
