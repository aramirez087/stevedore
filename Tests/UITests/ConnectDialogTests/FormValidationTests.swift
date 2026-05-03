import Core
import UIConnectDialog
import XCTest

/// Verifies per-scheme field validation rules.
@MainActor
final class ConnectDialogTestsFormValidation: XCTestCase {

    // MARK: - Display name

    func testEmptyDisplayNameFails() {
        let vm = makeViewModel()
        vm.displayName = ""
        vm.host = "example.com"
        vm.username = "user"

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.displayName])
    }

    func testWhitespaceOnlyDisplayNameFails() {
        let vm = makeViewModel()
        vm.displayName = "   "
        vm.host = "example.com"
        vm.username = "user"

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.displayName])
    }

    // MARK: - Host

    func testEmptyHostFails() {
        let vm = makeViewModel()
        vm.displayName = "Test"
        vm.host = ""
        vm.username = "user"

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.host])
    }

    // MARK: - Port range

    func testPortZeroFails() {
        let vm = makeViewModel()
        fillRequired(vm)
        vm.port = "0"

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.port])
    }

    func testPortAbove65535Fails() {
        let vm = makeViewModel()
        fillRequired(vm)
        vm.port = "65536"

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.port])
    }

    func testValidPortPasses() {
        let vm = makeViewModel()
        fillRequired(vm)
        vm.port = "22"

        XCTAssertTrue(vm.validate())
        XCTAssertNil(vm.validationErrors[.port])
    }

    func testEmptyPortPasses() {
        let vm = makeViewModel()
        fillRequired(vm)
        vm.port = ""

        XCTAssertTrue(vm.validate())
        XCTAssertNil(vm.validationErrors[.port])
    }

    // MARK: - SFTP

    func testSFTPPasswordRequiresUsername() {
        let vm = makeViewModel(scheme: .sftp)
        vm.displayName = "Test"
        vm.host = "sftp.example.com"
        vm.authMode = .password
        vm.username = ""

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.username])
    }

    func testSFTPSSHKeyRequiresKeyFile() {
        let vm = makeViewModel(scheme: .sftp)
        vm.displayName = "Test"
        vm.host = "sftp.example.com"
        vm.username = "alice"
        vm.authMode = .sshKey
        vm.privateKeyURL = nil

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.privateKey])
    }

    func testSFTPSSHKeyRequiresUsername() {
        let vm = makeViewModel(scheme: .sftp)
        vm.displayName = "Test"
        vm.host = "sftp.example.com"
        vm.username = ""
        vm.authMode = .sshKey
        vm.privateKeyURL = URL(filePath: "/tmp/id_rsa")

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.username])
    }

    func testSFTPAnonymousPassesWithoutUsername() {
        let vm = makeViewModel(scheme: .sftp)
        vm.displayName = "Test"
        vm.host = "sftp.example.com"
        vm.authMode = .anonymous
        vm.username = ""

        XCTAssertTrue(vm.validate())
        XCTAssertNil(vm.validationErrors[.username])
    }

    // MARK: - FTP

    func testFTPPasswordRequiresUsername() {
        let vm = makeViewModel(scheme: .ftp)
        vm.displayName = "Test"
        vm.host = "ftp.example.com"
        vm.authMode = .password
        vm.username = ""

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.username])
    }

    func testFTPAnonymousPassesWithoutUsername() {
        let vm = makeViewModel(scheme: .ftp)
        vm.displayName = "Test"
        vm.host = "ftp.example.com"
        vm.authMode = .anonymous
        vm.username = ""

        XCTAssertTrue(vm.validate())
    }

    // MARK: - WebDAV

    func testWebDAVPasswordRequiresUsername() {
        let vm = makeViewModel(scheme: .webdav)
        vm.displayName = "Test"
        vm.host = "dav.example.com"
        vm.authMode = .password
        vm.username = ""

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.username])
    }

    // MARK: - S3

    func testS3RequiresAccessKeyID() {
        let vm = makeViewModel(scheme: .s3)
        vm.displayName = "Test"
        vm.host = "s3.amazonaws.com"
        vm.authMode = .iam
        vm.s3AccessKeyID = ""
        vm.s3SecretKey = "secret"
        vm.s3Bucket = "my-bucket"

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.s3AccessKeyID])
    }

    func testS3RequiresSecretKey() {
        let vm = makeViewModel(scheme: .s3)
        vm.displayName = "Test"
        vm.host = "s3.amazonaws.com"
        vm.authMode = .iam
        vm.s3AccessKeyID = "AKIAIOSFODNN7EXAMPLE"
        vm.s3SecretKey = ""
        vm.s3Bucket = "my-bucket"

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.s3SecretKey])
    }

    func testS3RequiresBucket() {
        let vm = makeViewModel(scheme: .s3)
        vm.displayName = "Test"
        vm.host = "s3.amazonaws.com"
        vm.authMode = .iam
        vm.s3AccessKeyID = "AKIAIOSFODNN7EXAMPLE"
        vm.s3SecretKey = "secret"
        vm.s3Bucket = ""

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.s3Bucket])
    }

    func testS3ValidPasses() {
        let vm = makeViewModel(scheme: .s3)
        vm.displayName = "Test"
        vm.host = "s3.amazonaws.com"
        vm.authMode = .iam
        vm.s3AccessKeyID = "AKIAIOSFODNN7EXAMPLE"
        vm.s3SecretKey = "secret"
        vm.s3Bucket = "my-bucket"

        XCTAssertTrue(vm.validate())
        XCTAssertTrue(vm.validationErrors.isEmpty)
    }

    // MARK: - SMB

    func testSMBPasswordRequiresUsername() {
        let vm = makeViewModel(scheme: .smb)
        vm.displayName = "Test"
        vm.host = "fileserver.local"
        vm.authMode = .password
        vm.username = ""

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors[.username])
    }

    func testSMBAnonymousPassesWithoutUsername() {
        let vm = makeViewModel(scheme: .smb)
        vm.displayName = "Test"
        vm.host = "fileserver.local"
        vm.authMode = .anonymous
        vm.username = ""

        XCTAssertTrue(vm.validate())
    }

    // MARK: - AuthMode.supported

    func testAuthModeSupportedForSFTP() {
        let modes = AuthMode.supported(for: .sftp)
        XCTAssertTrue(modes.contains(.password))
        XCTAssertTrue(modes.contains(.sshKey))
        XCTAssertTrue(modes.contains(.anonymous))
        XCTAssertFalse(modes.contains(.iam))
    }

    func testAuthModeSupportedForS3() {
        let modes = AuthMode.supported(for: .s3)
        XCTAssertEqual(modes, [.iam])
    }

    // MARK: - Helpers

    private func makeViewModel(scheme: ConnectionScheme = .sftp) -> ConnectDialogViewModel {
        let vm = ConnectDialogViewModel(
            credentialStore: InMemoryCredentialStore(),
            connector: MockRemoteConnector()
        )
        vm.scheme = scheme
        return vm
    }

    private func fillRequired(_ vm: ConnectDialogViewModel) {
        vm.displayName = "Test"
        vm.host = "example.com"
        vm.username = "alice"
        vm.authMode = .password
    }
}
