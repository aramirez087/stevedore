import Core
import UIConnectDialog
import XCTest

/// Verifies the save and connect flows:
/// validate → store credential → invoke `onSave` / `onOpen` callbacks.
@MainActor
final class ConnectDialogTestsSaveFlow: XCTestCase {

    // MARK: - Save

    func testSaveStoresCredentialAndCallsOnSave() async throws {
        let store = InMemoryCredentialStore()
        let vm = makePasswordViewModel(credentialStore: store)
        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        XCTAssertNotNil(savedDescriptor, "onSave callback must be invoked")
        XCTAssertEqual(savedDescriptor?.host, "sftp.example.com")
        XCTAssertEqual(savedDescriptor?.scheme, .sftp)

        let stored = try await store.credential(for: savedDescriptor!.id)
        XCTAssertNotNil(stored, "Credential must be stored in the credential store")
    }

    func testSaveWithAnonymousAuthDoesNotStoreCredential() async throws {
        let store = InMemoryCredentialStore()
        let vm = makeAnonymousViewModel(credentialStore: store)
        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        XCTAssertNotNil(savedDescriptor)
        let ids = try await store.list()
        XCTAssertTrue(ids.isEmpty, "No credential should be stored for anonymous auth")
    }

    func testSaveFailsValidationWhenHostEmpty() async {
        let store = InMemoryCredentialStore()
        let vm = ConnectDialogViewModel(
            credentialStore: store,
            connector: MockRemoteConnector()
        )
        vm.scheme = .sftp
        vm.displayName = "Test"
        vm.host = ""
        var saveCalled = false
        vm.onSave = { _ in saveCalled = true }

        await vm.save()

        XCTAssertFalse(saveCalled, "onSave must not be called when validation fails")
        XCTAssertNotNil(vm.validationErrors[.host])
    }

    func testSaveDescriptorPreservesDisplayName() async {
        let store = InMemoryCredentialStore()
        let vm = makePasswordViewModel(credentialStore: store)
        vm.displayName = "My Dev Server"
        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        XCTAssertEqual(savedDescriptor?.displayName, "My Dev Server")
    }

    func testSaveTrimsWhitespaceFromHostAndDisplayName() async {
        let store = InMemoryCredentialStore()
        let vm = makePasswordViewModel(credentialStore: store)
        vm.displayName = "  My Server  "
        vm.host = "  sftp.example.com  "
        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        XCTAssertEqual(savedDescriptor?.displayName, "My Server")
        XCTAssertEqual(savedDescriptor?.host, "sftp.example.com")
    }

    func testSavePortIsParsedCorrectly() async {
        let store = InMemoryCredentialStore()
        let vm = makePasswordViewModel(credentialStore: store)
        vm.port = "2222"
        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        XCTAssertEqual(savedDescriptor?.port, 2222)
    }

    func testSaveEmptyPortResultsInNilPort() async {
        let store = InMemoryCredentialStore()
        let vm = makePasswordViewModel(credentialStore: store)
        vm.port = ""
        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        XCTAssertNil(savedDescriptor?.port)
    }

    // MARK: - Connect

    func testConnectCallsOnSaveThenOnOpen() async {
        let store = InMemoryCredentialStore()
        let vm = makePasswordViewModel(credentialStore: store)
        var saveCalled = false
        var openCalled = false
        vm.onSave = { _ in saveCalled = true }
        vm.onOpen = { _ in openCalled = true }

        await vm.connect()

        XCTAssertTrue(saveCalled, "onSave must be called during connect")
        XCTAssertTrue(openCalled, "onOpen must be called during connect")
    }

    func testConnectDoesNotCallOnOpenWhenValidationFails() async {
        let vm = ConnectDialogViewModel(
            credentialStore: InMemoryCredentialStore(),
            connector: MockRemoteConnector()
        )
        vm.scheme = .sftp
        vm.displayName = ""
        vm.host = ""
        var openCalled = false
        vm.onOpen = { _ in openCalled = true }

        await vm.connect()

        XCTAssertFalse(openCalled)
    }

    // MARK: - Cancel

    func testCancelInvokesOnCancel() {
        let vm = makePasswordViewModel(credentialStore: InMemoryCredentialStore())
        var cancelCalled = false
        vm.onCancel = { cancelCalled = true }

        vm.cancel()

        XCTAssertTrue(cancelCalled)
    }

    // MARK: - Editing existing descriptor

    func testInitWithExistingDescriptorPopulatesFields() {
        let descriptor = RemoteHostDescriptor(
            id: UUID(),
            displayName: "Prod Server",
            scheme: .sftp,
            host: "prod.example.com",
            port: 2222,
            username: "deploy",
            initialPath: nil
        )
        let vm = ConnectDialogViewModel(
            editing: descriptor,
            credentialStore: InMemoryCredentialStore(),
            connector: MockRemoteConnector()
        )

        XCTAssertEqual(vm.displayName, "Prod Server")
        XCTAssertEqual(vm.host, "prod.example.com")
        XCTAssertEqual(vm.port, "2222")
        XCTAssertEqual(vm.username, "deploy")
        XCTAssertEqual(vm.scheme, .sftp)
    }

    func testSavePreservesEditingID() async {
        let existingID = UUID()
        let descriptor = RemoteHostDescriptor(
            id: existingID,
            displayName: "My Server",
            scheme: .sftp,
            host: "sftp.example.com",
            port: nil,
            username: "alice",
            initialPath: nil
        )
        let store = InMemoryCredentialStore()
        let vm = ConnectDialogViewModel(
            editing: descriptor,
            credentialStore: store,
            connector: MockRemoteConnector()
        )
        vm.password = "secret"
        vm.authMode = .password
        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        XCTAssertEqual(savedDescriptor?.id, existingID, "Editing must preserve the original descriptor ID")
    }

    // MARK: - S3 save

    func testS3SaveStoresIAMCredential() async throws {
        let store = InMemoryCredentialStore()
        let vm = ConnectDialogViewModel(
            credentialStore: store,
            connector: MockRemoteConnector()
        )
        vm.scheme = .s3
        vm.displayName = "My Bucket"
        vm.host = "s3.amazonaws.com"
        vm.authMode = .iam
        vm.s3AccessKeyID = "AKIAIOSFODNN7EXAMPLE"
        vm.s3SecretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        vm.s3Bucket = "my-bucket"
        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        XCTAssertNotNil(savedDescriptor)
        let cred = try await store.credential(for: savedDescriptor!.id)
        XCTAssertNotNil(cred)
        XCTAssertEqual(cred?.username, "AKIAIOSFODNN7EXAMPLE")
    }

    // MARK: - Helpers

    private func makePasswordViewModel(
        credentialStore: any CredentialStore
    ) -> ConnectDialogViewModel {
        let vm = ConnectDialogViewModel(
            credentialStore: credentialStore,
            connector: MockRemoteConnector()
        )
        vm.scheme = .sftp
        vm.displayName = "Test Server"
        vm.host = "sftp.example.com"
        vm.username = "alice"
        vm.password = "hunter2"
        vm.authMode = .password
        return vm
    }

    private func makeAnonymousViewModel(
        credentialStore: any CredentialStore
    ) -> ConnectDialogViewModel {
        let vm = ConnectDialogViewModel(
            credentialStore: credentialStore,
            connector: MockRemoteConnector()
        )
        vm.scheme = .sftp
        vm.displayName = "Public Server"
        vm.host = "sftp.example.com"
        vm.authMode = .anonymous
        return vm
    }
}
