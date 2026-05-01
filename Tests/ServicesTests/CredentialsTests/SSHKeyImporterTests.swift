import Core
import ServicesCredentials
import XCTest

final class SSHKeyImporterTests: XCTestCase {
    let importer = SSHKeyImporter()

    // MARK: - Format detection

    func testDetectsOpenSSHNewFormat() throws {
        let format = try self.importer.detectFormat(data: SSHKeyFixtures.opensshNoPassphrase)
        XCTAssertEqual(format, .openssh)
    }

    func testDetectsPEMFormat() throws {
        let format = try self.importer.detectFormat(data: SSHKeyFixtures.pemNoPassphrase)
        XCTAssertEqual(format, .pem)
    }

    func testUnrecognizedFormatThrows() {
        let garbage = Data("not a key".utf8)
        XCTAssertThrowsError(try self.importer.detectFormat(data: garbage)) { error in
            guard case SSHKeyImporter.SSHKeyImportError.unrecognizedFormat = error else {
                XCTFail("Expected unrecognizedFormat, got \(error)")
                return
            }
        }
    }

    // MARK: - Passphrase detection (PEM)

    func testPEMNoPassphraseDetectedCorrectly() {
        let protected = self.importer.isPassphraseProtected(
            data: SSHKeyFixtures.pemNoPassphrase,
            format: .pem
        )
        XCTAssertFalse(protected)
    }

    func testPEMWithPassphraseDetectedCorrectly() {
        let protected = self.importer.isPassphraseProtected(
            data: SSHKeyFixtures.pemWithPassphrase,
            format: .pem
        )
        XCTAssertTrue(protected)
    }

    // MARK: - Passphrase detection (OpenSSH new format)

    func testOpenSSHNoPassphraseDetectedCorrectly() {
        let protected = self.importer.isPassphraseProtected(
            data: SSHKeyFixtures.opensshNoPassphrase,
            format: .openssh
        )
        XCTAssertFalse(protected)
    }

    func testOpenSSHWithPassphraseDetectedCorrectly() {
        let protected = self.importer.isPassphraseProtected(
            data: SSHKeyFixtures.opensshWithPassphrase,
            format: .openssh
        )
        XCTAssertTrue(protected)
    }

    // MARK: - Import

    func testImportNoPassphraseProducesPrivateKey() throws {
        let material = try self.importer.importKey(data: SSHKeyFixtures.pemNoPassphrase, passphrase: nil)
        guard case .privateKey(let pem, let stored) = material else {
            XCTFail("Expected .privateKey, got \(material.redactedDescription)")
            return
        }
        XCTAssertFalse(pem.isEmpty)
        XCTAssertNil(stored)
    }

    func testImportWithPassphraseStoresPassphrase() throws {
        let material = try self.importer.importKey(
            data: SSHKeyFixtures.opensshWithPassphrase,
            passphrase: "testpass"
        )
        guard case .privateKey(_, let stored) = material else {
            XCTFail("Expected .privateKey, got \(material.redactedDescription)")
            return
        }
        XCTAssertEqual(stored, "testpass")
    }

    func testImportRoundTripThroughPrivateModeStore() async throws {
        let material = try self.importer.importKey(data: SSHKeyFixtures.pemNoPassphrase, passphrase: nil)
        let credential = Credential(username: "git", material: material)
        let store = PrivateModeCredentialStore()
        let id = UUID()
        try await store.store(credential, for: id)
        let retrieved = try await store.credential(for: id)
        XCTAssertEqual(retrieved, credential)
    }
}
