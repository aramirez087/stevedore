import Core
@testable import UIConnectDialog
import XCTest

/// Verifies that no credential material appears in any test-connection failure message.
///
/// Seeds all credential fields with a recognizable sentinel string, then exercises
/// every `ConnectionTestResult.Status` variant and asserts the sentinel is absent
/// from all resulting `TestConnectionStatus.failure(message:)` values.
@MainActor
final class ConnectDialogRedactionTests: XCTestCase {
    private static let sentinel = "REDACT-ME"

    // MARK: - Failure message redaction

    func testAllStatusVariantsProduceRedactionSafeMessages() async throws {
        for status in ConnectionTestResult.Status.allCases {
            try await self.assertNoSentinelInMessage(for: status)
        }
    }

    func testAuthFailedMessageDoesNotContainSentinel() async throws {
        try await self.assertNoSentinelInMessage(for: .authenticationFailed)
    }

    func testUnreachableMessageDoesNotContainSentinel() async throws {
        try await self.assertNoSentinelInMessage(for: .unreachable)
    }

    func testTimeoutMessageDoesNotContainSentinel() async throws {
        try await self.assertNoSentinelInMessage(for: .timeout)
    }

    func testUnsupportedMessageDoesNotContainSentinel() async throws {
        try await self.assertNoSentinelInMessage(for: .unsupported)
    }

    func testUnknownMessageDoesNotContainSentinel() async throws {
        try await self.assertNoSentinelInMessage(for: .unknown)
    }

    func testThrownErrorMessageDoesNotContainSentinel() async {
        let connector = FakeRemoteConnector()
        await connector.setShouldThrow(true)
        let vm = self.seededViewModel(connector: connector)
        await vm.testConnection()
        self.assertNoSentinel(in: vm.testStatus)
    }

    // MARK: - Descriptor redaction (descriptors must not carry secret/credential fields)

    func testSavedDescriptorContainsNoCredentialFields() async {
        let store = InMemoryCredentialStore()
        let vm = self.seededViewModel(store: store)
        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }
        await vm.save()
        guard let descriptor = savedDescriptor else {
            XCTFail("onSave was not called")
            return
        }
        // Encode and verify none of the credential-only sentinels leaked into the descriptor.
        // Note: vm.username ("test-user") IS expected in the descriptor — username is metadata, not a secret.
        let encoded = (try? JSONEncoder().encode(descriptor)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertFalse(
            encoded.contains(Self.sentinel),
            "Descriptor JSON must not contain credential sentinel: \(encoded)"
        )
    }

    // MARK: - Helpers

    private func assertNoSentinelInMessage(for status: ConnectionTestResult.Status) async throws {
        let connector = FakeRemoteConnector()
        await connector.setResult(ConnectionTestResult(status: status, latencyMilliseconds: nil))
        let vm = self.seededViewModel(connector: connector)
        await vm.testConnection()
        self.assertNoSentinel(in: vm.testStatus)
    }

    private func assertNoSentinel(in status: TestConnectionStatus) {
        if case .failure(let message) = status {
            XCTAssertFalse(
                message.contains(Self.sentinel),
                "Failure message contains sentinel credential material: \(message)"
            )
        }
        // .success and .idle cannot contain credential material by design
    }

    private func seededViewModel(
        connector: FakeRemoteConnector = FakeRemoteConnector(),
        store: InMemoryCredentialStore = InMemoryCredentialStore()
    ) -> ConnectDialogViewModel {
        let vm = ConnectDialogViewModel(
            credentialStore: store,
            connector: connector,
            keyPickerHandler: { nil }
        )
        vm.selectedScheme = .sftp
        vm.hostname = "example.com"
        // username is metadata stored in the descriptor — it is NOT credential material
        vm.username = "test-user"
        // Credential-only fields seeded with sentinel — must never leak into test status messages
        vm.password = Self.sentinel
        vm.sshKeyPassphrase = Self.sentinel
        vm.awsAccessKeyID = Self.sentinel
        vm.awsSecretKey = Self.sentinel
        return vm
    }
}
