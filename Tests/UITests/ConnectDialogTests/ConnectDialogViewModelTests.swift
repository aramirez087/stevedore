import Core
@testable import UIConnectDialog
import XCTest

@MainActor
final class ConnectDialogViewModelTests: XCTestCase {
    func testDefaultInit() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.selectedScheme, .sftp)
        XCTAssertEqual(vm.authMode, .password)
        XCTAssertFalse(vm.showPassword)
        XCTAssertEqual(vm.testStatus, .idle)
        XCTAssertTrue(vm.validationErrors.isEmpty)
    }

    func testEditInit() {
        let descriptor = RemoteHostDescriptor(
            id: UUID(),
            displayName: "My Server",
            scheme: .ftp,
            host: "ftp.example.com",
            port: 2121,
            username: "alice",
            initialPath: FilePath(scheme: .ftp, posix: "/pub")
        )
        let vm = ConnectDialogViewModel(
            editing: descriptor,
            credentialStore: InMemoryCredentialStore(),
            connector: FakeRemoteConnector(),
            keyPickerHandler: { nil }
        )
        XCTAssertEqual(vm.selectedScheme, .ftp)
        XCTAssertEqual(vm.hostname, "ftp.example.com")
        XCTAssertEqual(vm.portString, "2121")
        XCTAssertEqual(vm.username, "alice")
        XCTAssertEqual(vm.displayName, "My Server")
    }

    func testSchemeSwitchSFTPToS3ResetsAuthMode() {
        let vm = makeViewModel(scheme: .sftp)
        vm.authMode = .sshKey
        vm.selectedScheme = .s3
        XCTAssertEqual(vm.authMode, .iam)
    }

    func testSchemeSwitchSFTPToFTPWithSSHKeyResetsToPassword() {
        let vm = makeViewModel(scheme: .sftp)
        vm.authMode = .sshKey
        vm.selectedScheme = .ftp
        XCTAssertEqual(vm.authMode, .password)
    }

    func testCancelClearsValidationErrorsAndCallsCallback() {
        let vm = makeViewModel()
        vm.hostname = ""
        vm.validate()
        XCTAssertFalse(vm.validationErrors.isEmpty)
        var cancelCalled = false
        vm.onCancel = { cancelCalled = true }
        vm.cancel()
        XCTAssertTrue(vm.validationErrors.isEmpty)
        XCTAssertTrue(cancelCalled)
    }

    func testBuildDescriptorDefaultsDisplayNameToHostname() {
        let vm = makeViewModel()
        vm.hostname = "sftp.example.com"
        vm.displayName = ""
        let descriptor = vm.buildDescriptor()
        XCTAssertEqual(descriptor.displayName, "sftp.example.com")
    }

    func testBuildDescriptorUsesCustomDisplayName() {
        let vm = makeViewModel()
        vm.hostname = "sftp.example.com"
        vm.displayName = "My SFTP"
        let descriptor = vm.buildDescriptor()
        XCTAssertEqual(descriptor.displayName, "My SFTP")
    }

    func testStableUUIDOnRepeatedBuildDescriptor() {
        let vm = makeViewModel()
        vm.hostname = "example.com"
        let id1 = vm.buildDescriptor().id
        let id2 = vm.buildDescriptor().id
        XCTAssertEqual(id1, id2)
    }

    func testAvailableModesForScheme() {
        XCTAssertEqual(ConnectDialogViewModel.availableModes(for: .sftp), [.password, .sshKey])
        XCTAssertEqual(ConnectDialogViewModel.availableModes(for: .ftp), [.password, .anonymous])
        XCTAssertEqual(ConnectDialogViewModel.availableModes(for: .webdav), [.password])
        XCTAssertEqual(ConnectDialogViewModel.availableModes(for: .s3), [.iam, .password])
        XCTAssertEqual(ConnectDialogViewModel.availableModes(for: .smb), [.password])
    }

    func testDefaultPorts() {
        XCTAssertEqual(ConnectDialogViewModel.defaultPort(for: .sftp), 22)
        XCTAssertEqual(ConnectDialogViewModel.defaultPort(for: .ftp), 21)
        XCTAssertEqual(ConnectDialogViewModel.defaultPort(for: .webdav), 443)
        XCTAssertEqual(ConnectDialogViewModel.defaultPort(for: .smb), 445)
        XCTAssertNil(ConnectDialogViewModel.defaultPort(for: .s3))
    }
}
