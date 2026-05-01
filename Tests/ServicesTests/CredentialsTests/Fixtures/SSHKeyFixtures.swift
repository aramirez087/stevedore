import Foundation

/// Synthetic SSH key fixtures for parser testing.
///
/// FIXTURE ONLY — never used for real authentication. These are not valid
/// cryptographic keys; only the header/structure fields are correct for
/// format-detection and passphrase-detection tests.
enum SSHKeyFixtures {
    // MARK: - OpenSSH new format

    /// Minimal OpenSSH new-format key with cipher "none" (no passphrase).
    static let opensshNoPassphrase: Data = makeOpenSSHPEM(cipher: "none")

    /// Minimal OpenSSH new-format key with cipher "aes256-ctr" (passphrase protected).
    static let opensshWithPassphrase: Data = makeOpenSSHPEM(cipher: "aes256-ctr")

    // MARK: - PEM format

    /// Minimal PEM RSA key without passphrase protection.
    static let pemNoPassphrase: Data = .init(
        """
        -----BEGIN RSA PRIVATE KEY-----
        MIIBOAIBAAJBALRiMLAHudeSA/xKl1oTCwqtJXHKLSKeHmxPBVfT9R3FnE8DVJEE
        pnU7RlcRXRJyAOvFfJEPR+SicPgnjbkDnxECAwEAAQJAQGjDVgJUenEjBriERbhR
        -----END RSA PRIVATE KEY-----
        """.utf8
    )

    /// Minimal PEM RSA key with passphrase protection headers.
    static let pemWithPassphrase: Data = .init(
        """
        -----BEGIN RSA PRIVATE KEY-----
        Proc-Type: 4,ENCRYPTED
        DEK-Info: AES-128-CBC,AABB00112233445566778899AABBCCDD

        MIIBOAIBAAJBALRiMLAHudeSA/xKl1oTCwqtJXHKLSKeHmxPBVfT9R3FnE8DVJEE
        pnU7RlcRXRJyAOvFfJEPR+SicPgnjbkDnxECAwEAAQJAQGjDVgJUenEjBriERbhR
        -----END RSA PRIVATE KEY-----
        """.utf8
    )

    // MARK: - Private factory

    private static func makeOpenSSHPEM(cipher: String) -> Data {
        var binary = Data()
        binary.append(contentsOf: Data("openssh-key-v1\0".utf8))
        let cipherBytes = Data(cipher.utf8)
        self.appendBigEndian(&binary, UInt32(cipherBytes.count))
        binary.append(cipherBytes)
        // KDF: "none"
        self.appendBigEndian(&binary, 4)
        binary.append(contentsOf: Data("none".utf8))
        // KDF options length: 0
        self.appendBigEndian(&binary, 0)
        // Number of keys: 1
        self.appendBigEndian(&binary, 1)
        let b64 = binary.base64EncodedString(options: .lineLength64Characters)
        let pem = "-----BEGIN OPENSSH PRIVATE KEY-----\n\(b64)\n-----END OPENSSH PRIVATE KEY-----\n"
        return Data(pem.utf8)
    }

    private static func appendBigEndian(_ data: inout Data, _ value: UInt32) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }
}
