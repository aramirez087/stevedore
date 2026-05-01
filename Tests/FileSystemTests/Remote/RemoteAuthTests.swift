import Core
@testable import FileSystemRemote
import XCTest

final class RemoteAuthTests: XCTestCase {
    // MARK: - SFTP

    func testSFTPPasswordCredential() {
        let host = RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "example.com", port: 22)
        let cred = Credential(username: "alice", material: .password("s3cret"))
        let strategy = RemoteAuth.strategy(for: cred, host: host)
        guard case .password(let user, let pass) = strategy else {
            return XCTFail("Expected .password, got \(strategy)")
        }
        XCTAssertEqual(user, "alice")
        XCTAssertEqual(pass, "s3cret")
    }

    func testSFTPPrivateKeyCredential() {
        let host = RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "example.com", port: 22)
        let pem = "-----BEGIN PRIVATE KEY-----\nbase64\n-----END PRIVATE KEY-----"
        let cred = Credential(username: "bob", material: .privateKey(pem: pem, passphrase: "phrase"))
        let strategy = RemoteAuth.strategy(for: cred, host: host)
        guard case .privateKey(let user, let actualPem, let passphrase) = strategy else {
            return XCTFail("Expected .privateKey, got \(strategy)")
        }
        XCTAssertEqual(user, "bob")
        XCTAssertEqual(actualPem, pem)
        XCTAssertEqual(passphrase, "phrase")
    }

    func testSFTPNilCredentialIsAnonymous() {
        let host = RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "example.com", port: 22)
        let strategy = RemoteAuth.strategy(for: nil, host: host)
        guard case .anonymous = strategy else {
            return XCTFail("Expected .anonymous, got \(strategy)")
        }
    }

    // MARK: - FTP

    func testFTPPasswordCredential() {
        let host = RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "ftp.example.com", port: 21)
        let cred = Credential(username: "user", material: .password("pass"))
        let strategy = RemoteAuth.strategy(for: cred, host: host)
        guard case .password(let user, let pass) = strategy else {
            return XCTFail("Expected .password, got \(strategy)")
        }
        XCTAssertEqual(user, "user")
        XCTAssertEqual(pass, "pass")
    }

    func testFTPNilCredentialIsAnonymous() {
        let host = RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "ftp.example.com", port: 21)
        XCTAssertEqual(RemoteAuth.strategy(for: nil, host: host), .anonymous)
    }

    // MARK: - WebDAV

    func testWebDAVPasswordCredential() {
        let host = RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "dav.example.com", port: 443)
        let cred = Credential(username: "user", material: .password("pass"))
        let strategy = RemoteAuth.strategy(for: cred, host: host)
        guard case .password = strategy else {
            return XCTFail("Expected .password, got \(strategy)")
        }
    }

    func testWebDAVBearerToken() {
        let host = RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "dav.example.com", port: 443)
        let cred = Credential(username: "user", material: .oauthToken("mytoken"))
        let strategy = RemoteAuth.strategy(for: cred, host: host)
        guard case .bearerToken(let token) = strategy else {
            return XCTFail("Expected .bearerToken, got \(strategy)")
        }
        XCTAssertEqual(token, "mytoken")
    }

    // MARK: - S3

    func testS3AwsSig4Credential() {
        let host = RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.us-west-2.amazonaws.com", port: 443)
        let cred = Credential(username: "AKID", material: .password("secretkey"))
        let strategy = RemoteAuth.strategy(for: cred, host: host, region: "us-west-2")
        guard case .awsSig4(let keyID, let secret, let region) = strategy else {
            return XCTFail("Expected .awsSig4, got \(strategy)")
        }
        XCTAssertEqual(keyID, "AKID")
        XCTAssertEqual(secret, "secretkey")
        XCTAssertEqual(region, "us-west-2")
    }

    func testS3NilCredentialIsAnonymous() {
        let host = RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.amazonaws.com", port: 443)
        XCTAssertEqual(RemoteAuth.strategy(for: nil, host: host), .anonymous)
    }
}
