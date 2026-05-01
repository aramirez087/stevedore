import Core
import Foundation

/// Parses OpenSSH private key files into `CredentialMaterial` for storage.
///
/// This importer handles format detection and passphrase-protection detection
/// only. It does not decrypt encrypted key blobs — that is deferred to the
/// SSH connection layer (Citadel) which receives the raw PEM string and
/// passphrase at connect time.
public struct SSHKeyImporter: Sendable {
    // MARK: - Public types

    public enum SSHKeyFormat: Sendable {
        /// Legacy PEM format (`-----BEGIN RSA/EC/DSA PRIVATE KEY-----`).
        case pem
        /// OpenSSH new format (`-----BEGIN OPENSSH PRIVATE KEY-----`).
        case openssh
    }

    public enum SSHKeyImportError: Error, Sendable {
        case unrecognizedFormat
        case passphraseRequired
        case unsupportedKeyType(String)
    }

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Public API

    /// Detects the SSH key format from the file's PEM-style header.
    public func detectFormat(data: Data) throws -> SSHKeyFormat {
        guard let header = String(data: data.prefix(200), encoding: .utf8) else {
            throw SSHKeyImportError.unrecognizedFormat
        }
        if header.contains("-----BEGIN OPENSSH PRIVATE KEY-----") {
            return .openssh
        }
        let isPemLegacy = header.contains("-----BEGIN RSA PRIVATE KEY-----")
            || header.contains("-----BEGIN EC PRIVATE KEY-----")
            || header.contains("-----BEGIN DSA PRIVATE KEY-----")
        if isPemLegacy {
            return .pem
        }
        throw SSHKeyImportError.unrecognizedFormat
    }

    /// Returns `true` when the key requires a passphrase to decrypt.
    public func isPassphraseProtected(data: Data, format: SSHKeyFormat) -> Bool {
        switch format {
        case .pem:
            guard let content = String(data: data, encoding: .utf8) else { return false }
            return content.contains("Proc-Type: 4,ENCRYPTED")
        case .openssh:
            return self.opensshHasPassphrase(data: data)
        }
    }

    /// Validates the key format and returns a `CredentialMaterial` ready for storage.
    ///
    /// The passphrase (if any) is stored alongside the PEM string so the
    /// connection layer can decrypt the key blob at connect time.
    public func importKey(data: Data, passphrase: String?) throws -> CredentialMaterial {
        _ = try self.detectFormat(data: data)
        guard let pem = String(data: data, encoding: .utf8) else {
            throw SSHKeyImportError.unrecognizedFormat
        }
        return .privateKey(pem: pem, passphrase: passphrase)
    }

    // MARK: - Private helpers

    private func opensshHasPassphrase(data: Data) -> Bool {
        guard let body = self.extractBase64Body(from: data) else { return false }
        guard let decoded = Data(base64Encoded: body) else { return false }

        let magic = Data("openssh-key-v1\0".utf8)
        guard decoded.count > magic.count + 4 else { return false }
        guard decoded.prefix(magic.count) == magic else { return false }

        let offset = magic.count
        guard offset + 4 <= decoded.count else { return false }

        let cipherLen = self.readBigEndianUInt32(from: decoded, at: offset)
        let nameStart = offset + 4
        guard nameStart + Int(cipherLen) <= decoded.count else { return false }

        let cipherName = String(
            data: decoded.subdata(in: nameStart ..< (nameStart + Int(cipherLen))),
            encoding: .utf8
        ) ?? ""
        return cipherName != "none"
    }

    private func extractBase64Body(from data: Data) -> String? {
        guard let content = String(data: data, encoding: .utf8) else { return nil }
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
            .joined()
    }

    private func readBigEndianUInt32(from data: Data, at offset: Int) -> UInt32 {
        let slice = data[offset ..< (offset + 4)]
        return slice.reduce(0) { acc, byte in (acc << 8) | UInt32(byte) }
    }
}
