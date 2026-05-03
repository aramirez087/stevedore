import Core
import ServicesCredentials
import XCTest

final class CredentialRedactionTests: XCTestCase {
    func testPasswordMaterialIsRedacted() {
        let secret = "super-secret-password-99"
        let material = CredentialMaterial.password(secret)
        XCTAssertFalse(material.redactedDescription.contains(secret))
        XCTAssertEqual(material.redactedDescription, "<password [redacted]>")
    }

    func testPrivateKeyMaterialIsRedacted() {
        let keyPem = "-----BEGIN RSA PRIVATE KEY-----\nFAKEDATA\n-----END RSA PRIVATE KEY-----"
        let passphrase = "my-secret-passphrase"
        let material = CredentialMaterial.privateKey(pem: keyPem, passphrase: passphrase)
        let desc = material.redactedDescription
        XCTAssertFalse(desc.contains(keyPem))
        XCTAssertFalse(desc.contains(passphrase))
        XCTAssertEqual(desc, "<privateKey [redacted]>")
    }

    func testOAuthTokenMaterialIsRedacted() {
        let token = "ghp_SuperSecretOAuthToken12345"
        let material = CredentialMaterial.oauthToken(token)
        XCTAssertFalse(material.redactedDescription.contains(token))
        XCTAssertEqual(material.redactedDescription, "<oauthToken [redacted]>")
    }

    func testCredentialRedactedDescriptionExcludesPassword() {
        let secret = "hunter2"
        let credential = Credential(username: "alice", material: .password(secret))
        let desc = credential.redactedDescription
        XCTAssertFalse(desc.contains(secret))
        XCTAssertTrue(desc.contains("[redacted]"))
        XCTAssertTrue(desc.contains("alice"))
    }

    func testCredentialRedactedDescriptionExcludesPrivateKey() {
        let keyData = "SUPERSECRETKEYDATA"
        let credential = Credential(username: nil, material: .privateKey(pem: keyData, passphrase: "pass"))
        let desc = credential.redactedDescription
        XCTAssertFalse(desc.contains(keyData))
        XCTAssertFalse(desc.contains("pass"))
        XCTAssertTrue(desc.contains("[redacted]"))
    }

    func testCredentialRedactedDescriptionExcludesOAuthToken() {
        let token = "eyJhbGciOiJSUzI1NiJ9.secret"
        let credential = Credential(username: "bot", material: .oauthToken(token))
        let desc = credential.redactedDescription
        XCTAssertFalse(desc.contains(token))
        XCTAssertTrue(desc.contains("[redacted]"))
        XCTAssertTrue(desc.contains("bot"))
    }

    func testNilUsernameDisplayedSafely() {
        let credential = Credential(username: nil, material: .password("secret"))
        XCTAssertTrue(credential.redactedDescription.contains("nil"))
    }
}
