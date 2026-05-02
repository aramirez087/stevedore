import Core
@testable import UIConnectDialog
import XCTest

@MainActor
final class ConnectDialogSaveFlowTests: XCTestCase {
    func testSaveWithInvalidFormDoesNotCallOnSave() async {
        let store = InMemoryCredentialStore()
        let vm = makeViewModel(scheme: .sftp, store: store)
        vm.hostname = ""
        var saveCalled = false
        vm.onSave = { _ in saveCalled = true }

        await vm.save()

        XCTAssertFalse(saveCalled)
    }

    func testSaveSuccessStoresCredentialForCorrectHostID() async throws {
        let store = InMemoryCredentialStore()
        let vm = makeViewModel(scheme: .sftp, store: store)
        vm.hostname = "example.com"
        vm.username = "alice"
        vm.password = "hunter2"

        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        guard let descriptor = savedDescriptor else {
            XCTFail("onSave not called")
            return
        }
        let stored = try await store.credential(for: descriptor.id)
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.username, "alice")
    }

    func testSaveCallsOnSaveWithMatchingDescriptorID() async {
        let store = InMemoryCredentialStore()
        let vm = makeViewModel(scheme: .sftp, store: store)
        vm.hostname = "example.com"
        vm.username = "alice"

        var receivedID: UUID?
        let builtID = vm.buildDescriptor().id
        vm.onSave = { receivedID = $0.id }

        await vm.save()

        XCTAssertEqual(receivedID, builtID)
    }

    func testConnectCallsOnSaveThenOnConnect() async {
        let store = InMemoryCredentialStore()
        let vm = makeViewModel(scheme: .sftp, store: store)
        vm.hostname = "example.com"
        vm.username = "alice"

        var callOrder: [String] = []
        vm.onSave = { _ in callOrder.append("save") }
        vm.onConnect = { _ in callOrder.append("connect") }

        await vm.connect()

        XCTAssertEqual(callOrder, ["save", "connect"])
    }

    func testIAMS3DoesNotStoreCredential() async throws {
        let store = InMemoryCredentialStore()
        let vm = makeViewModel(scheme: .s3, store: store)
        vm.s3Bucket = "my-bucket"
        vm.s3Region = "us-east-1"
        vm.authMode = .iam

        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        guard let descriptor = savedDescriptor else {
            XCTFail("onSave not called")
            return
        }
        let stored = try await store.credential(for: descriptor.id)
        XCTAssertNil(stored)
    }

    func testAnonymousFTPDoesNotStoreCredential() async throws {
        let store = InMemoryCredentialStore()
        let vm = makeViewModel(scheme: .ftp, store: store)
        vm.hostname = "ftp.example.com"
        vm.authMode = .anonymous

        var savedDescriptor: RemoteHostDescriptor?
        vm.onSave = { savedDescriptor = $0 }

        await vm.save()

        guard let descriptor = savedDescriptor else {
            XCTFail("onSave not called")
            return
        }
        let stored = try await store.credential(for: descriptor.id)
        XCTAssertNil(stored)
    }
}
