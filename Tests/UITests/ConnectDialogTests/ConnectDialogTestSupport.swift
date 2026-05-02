import Core
import Foundation
@testable import UIConnectDialog

// MARK: - FakeRemoteConnector

/// Test double for `RemoteConnector`. Captures calls for assertion; never touches the network.
actor FakeRemoteConnector: RemoteConnector {
    struct TestCall: Sendable {
        let descriptor: RemoteHostDescriptor
        let credential: Credential?
    }

    private(set) var testCalls: [TestCall] = []

    var testResultToReturn: ConnectionTestResult = .init(status: .success, latencyMilliseconds: 42)
    var shouldThrow: Bool = false

    func test(
        _ host: RemoteHostDescriptor,
        credential: Credential?
    ) async throws -> ConnectionTestResult {
        self.testCalls.append(TestCall(descriptor: host, credential: credential))
        if self.shouldThrow {
            throw NSError(domain: "FakeError", code: 1)
        }
        return self.testResultToReturn
    }

    func open(
        _ host: RemoteHostDescriptor,
        credential: Credential?
    ) async throws -> any FileSystemProvider {
        fatalError("FakeRemoteConnector.open should not be called in unit tests")
    }
}

// MARK: - Factories

@MainActor
func makeViewModel(
    scheme: ConnectionScheme = .sftp,
    connector: FakeRemoteConnector = FakeRemoteConnector(),
    store: InMemoryCredentialStore = InMemoryCredentialStore(),
    keyPicker: @escaping KeyPickerHandler = { nil }
) -> ConnectDialogViewModel {
    let vm = ConnectDialogViewModel(
        credentialStore: store,
        connector: connector,
        keyPickerHandler: keyPicker
    )
    vm.selectedScheme = scheme
    return vm
}
