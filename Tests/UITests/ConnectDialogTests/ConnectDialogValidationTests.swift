import Core
@testable import UIConnectDialog
import XCTest

@MainActor
final class ConnectDialogValidationTests: XCTestCase {
    // MARK: - SFTP

    func testSFTPEmptyHostnameFails() {
        let vm = makeViewModel(scheme: .sftp)
        vm.username = "alice"
        vm.hostname = ""
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .hostname })
    }

    func testSFTPWhitespaceOnlyHostnameFails() {
        let vm = makeViewModel(scheme: .sftp)
        vm.username = "alice"
        vm.hostname = "   "
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .hostname })
    }

    func testSFTPPortZeroFails() {
        let vm = makeViewModel(scheme: .sftp)
        vm.hostname = "example.com"
        vm.username = "alice"
        vm.portString = "0"
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .port })
    }

    func testSFTPPort65536Fails() {
        let vm = makeViewModel(scheme: .sftp)
        vm.hostname = "example.com"
        vm.username = "alice"
        vm.portString = "65536"
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .port })
    }

    func testSFTPPort22Passes() {
        let vm = makeViewModel(scheme: .sftp)
        vm.hostname = "example.com"
        vm.username = "alice"
        vm.portString = "22"
        XCTAssertTrue(vm.validate())
        XCTAssertFalse(vm.validationErrors.contains { $0.field == .port })
    }

    func testSFTPSSHKeyAuthWithNilURLFails() {
        let vm = makeViewModel(scheme: .sftp)
        vm.hostname = "example.com"
        vm.username = "alice"
        vm.authMode = .sshKey
        vm.sshKeyURL = nil
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .sshKeyURL })
    }

    func testSFTPSSHKeyAuthWithURLPasses() {
        let vm = makeViewModel(scheme: .sftp)
        vm.hostname = "example.com"
        vm.username = "alice"
        vm.authMode = .sshKey
        vm.sshKeyURL = URL(fileURLWithPath: "/tmp/id_rsa")
        XCTAssertTrue(vm.validate())
    }

    // MARK: - FTP

    func testFTPAnonymousOnlyRequiresHostname() {
        let vm = makeViewModel(scheme: .ftp)
        vm.hostname = "ftp.example.com"
        vm.authMode = .anonymous
        vm.username = ""
        XCTAssertTrue(vm.validate())
    }

    func testFTPEmptyHostnameFails() {
        let vm = makeViewModel(scheme: .ftp)
        vm.hostname = ""
        XCTAssertFalse(vm.validate())
    }

    // MARK: - S3

    func testS3EmptyBucketFails() {
        let vm = makeViewModel(scheme: .s3)
        vm.s3Bucket = ""
        vm.s3Region = "us-east-1"
        vm.authMode = .iam
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .s3Bucket })
    }

    func testS3EmptyRegionFails() {
        let vm = makeViewModel(scheme: .s3)
        vm.s3Bucket = "my-bucket"
        vm.s3Region = ""
        vm.authMode = .iam
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .s3Region })
    }

    func testS3PasswordAuthEmptyAccessKeyFails() {
        let vm = makeViewModel(scheme: .s3)
        vm.s3Bucket = "my-bucket"
        vm.s3Region = "us-east-1"
        vm.authMode = .password
        vm.awsAccessKeyID = ""
        vm.awsSecretKey = "secret"
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .awsAccessKeyID })
    }

    func testS3PasswordAuthEmptySecretKeyFails() {
        let vm = makeViewModel(scheme: .s3)
        vm.s3Bucket = "my-bucket"
        vm.s3Region = "us-east-1"
        vm.authMode = .password
        vm.awsAccessKeyID = "AKID123"
        vm.awsSecretKey = ""
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .awsSecretKey })
    }

    // MARK: - WebDAV

    func testWebDAVValidHostnameAndUsernamePasses() {
        let vm = makeViewModel(scheme: .webdav)
        vm.hostname = "webdav.example.com"
        vm.username = "bob"
        XCTAssertTrue(vm.validate())
    }

    // MARK: - SMB

    func testSMBEmptyHostnameFails() {
        let vm = makeViewModel(scheme: .smb)
        vm.hostname = ""
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .hostname })
    }

    func testPortNonNumericFails() {
        let vm = makeViewModel(scheme: .sftp)
        vm.hostname = "example.com"
        vm.username = "alice"
        vm.portString = "abc"
        XCTAssertFalse(vm.validate())
        XCTAssertTrue(vm.validationErrors.contains { $0.field == .port })
    }

    func testEmptyPortStringPassesWithValidHostname() {
        let vm = makeViewModel(scheme: .sftp)
        vm.hostname = "example.com"
        vm.username = "alice"
        vm.portString = ""
        XCTAssertTrue(vm.validate())
    }
}
