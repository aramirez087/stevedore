import Foundation

/// A stored secret bound to a `RemoteHostDescriptor`.
///
/// Codable so `InMemoryCredentialStore` can mirror the on-disk shape used by
/// the real Keychain-backed store, but production code should never persist
/// this type to disk in cleartext.
public struct Credential: Hashable, Sendable, Codable {
    public let username: String?
    public let material: CredentialMaterial

    public init(username: String?, material: CredentialMaterial) {
        self.username = username
        self.material = material
    }
}

/// The secret payload of a `Credential`.
public enum CredentialMaterial: Hashable, Sendable, Codable {
    case password(String)
    case privateKey(pem: String, passphrase: String?)
    case oauthToken(String)

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CredentialMaterialCodingKeys.self)
        let discriminator = try container.decode(CredentialMaterialKind.self, forKey: .kind)
        switch discriminator {
        case .password:
            self = try .password(container.decode(String.self, forKey: .password))
        case .privateKey:
            let pem = try container.decode(String.self, forKey: .pem)
            let passphrase = try container.decodeIfPresent(String.self, forKey: .passphrase)
            self = .privateKey(pem: pem, passphrase: passphrase)
        case .oauthToken:
            self = try .oauthToken(container.decode(String.self, forKey: .token))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CredentialMaterialCodingKeys.self)
        switch self {
        case .password(let value):
            try container.encode(CredentialMaterialKind.password, forKey: .kind)
            try container.encode(value, forKey: .password)
        case .privateKey(let pem, let passphrase):
            try container.encode(CredentialMaterialKind.privateKey, forKey: .kind)
            try container.encode(pem, forKey: .pem)
            try container.encodeIfPresent(passphrase, forKey: .passphrase)
        case .oauthToken(let token):
            try container.encode(CredentialMaterialKind.oauthToken, forKey: .kind)
            try container.encode(token, forKey: .token)
        }
    }
}

private enum CredentialMaterialCodingKeys: String, CodingKey {
    case kind
    case password
    case pem
    case passphrase
    case token
}

private enum CredentialMaterialKind: String, Codable {
    case password
    case privateKey
    case oauthToken
}
