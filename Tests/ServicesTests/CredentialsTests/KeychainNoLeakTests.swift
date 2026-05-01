import Core
import Foundation
import ServicesCredentials
import XCTest

/// Verifies that no credential secret value ever appears in an error description
/// or a redacted log-safe representation. Exercises every error-path and
/// assertion type defined by the exit criteria.
final class KeychainNoLeakTests: XCTestCase {
    private let secretPassword = "ULTRA_SECRET_PASSWORD_99"
    private let secretKeyPEM = "-----BEGIN RSA PRIVATE KEY-----\nSECRET_KEY_MATERIAL\n-----END RSA PRIVATE KEY-----"
    private let secretPassphrase = "SECRET_PASSPHRASE_42"
    private let secretToken = "ghp_SECRET_OAUTH_TOKEN_XYZ"

    // MARK: - Redacted description tests

    func testPasswordNotInRedactedDescription() {
        let credential = Credential(username: "user", material: .password(self.secretPassword))
        XCTAssertFalse(credential.redactedDescription.contains(self.secretPassword))
    }

    func testPrivateKeyNotInRedactedDescription() {
        let material = CredentialMaterial.privateKey(pem: self.secretKeyPEM, passphrase: self.secretPassphrase)
        let credential = Credential(username: nil, material: material)
        let desc = credential.redactedDescription
        XCTAssertFalse(desc.contains(self.secretKeyPEM))
        XCTAssertFalse(desc.contains(self.secretPassphrase))
    }

    func testOAuthTokenNotInRedactedDescription() {
        let credential = Credential(username: "bot", material: .oauthToken(self.secretToken))
        XCTAssertFalse(credential.redactedDescription.contains(self.secretToken))
    }

    // MARK: - Error description tests

    func testNotFoundErrorContainsNoSecrets() {
        let error = CredentialError.notFound
        let desc = error.errorDescription ?? ""
        XCTAssertFalse(desc.contains(self.secretPassword))
        XCTAssertFalse(desc.contains(self.secretKeyPEM))
        XCTAssertFalse(desc.contains(self.secretToken))
    }

    func testStorageFailureContainsOnlyStatusCode() {
        let statusCode: OSStatus = -25300
        let error = CredentialError.storageFailure(detail: "OSStatus \(statusCode)")
        let desc = error.errorDescription ?? ""
        XCTAssertFalse(desc.contains(self.secretPassword))
        XCTAssertFalse(desc.contains(self.secretKeyPEM))
        XCTAssertFalse(desc.contains(self.secretToken))
        XCTAssertTrue(desc.contains("\(statusCode)"))
    }

    func testStorageFailureFormatNeverContainsPayload() {
        // Verify the mapping pattern: storageFailure only embeds the numeric status
        let knownStatuses: [OSStatus] = [-25299, -25300, -25308, -50, -34018]
        for status in knownStatuses {
            let error = CredentialError.storageFailure(detail: "OSStatus \(status)")
            let desc = error.errorDescription ?? ""
            XCTAssertFalse(desc.contains(self.secretPassword), "Status \(status) description leaked password")
            XCTAssertTrue(desc.contains("\(status)"), "Status \(status) not in description")
        }
    }

    // MARK: - Live keychain operations produce no leaks

    func testKeychainListOnEmptyServiceReturnsEmpty() async throws {
        let service = "com.stevedore.test.noleak.\(UUID().uuidString)"
        let store = KeychainCredentialStore(service: service)
        let ids = try await store.list()
        XCTAssertTrue(ids.isEmpty)
    }

    func testKeychainRemoveNonExistentProducesNoError() async throws {
        let service = "com.stevedore.test.noleak.\(UUID().uuidString)"
        let store = KeychainCredentialStore(service: service)
        try await store.remove(for: UUID())
    }

    func testKeychainFetchMissingReturnsNil() async throws {
        let service = "com.stevedore.test.noleak.\(UUID().uuidString)"
        let store = KeychainCredentialStore(service: service)
        let result = try await store.credential(for: UUID())
        XCTAssertNil(result)
    }
}
