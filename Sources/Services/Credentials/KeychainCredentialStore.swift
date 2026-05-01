import Core
import Foundation
import Security

/// Keychain-backed `CredentialStore` for production use.
///
/// Credentials are JSON-encoded and stored as `kSecClassGenericPassword` items
/// with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — they survive
/// sleep/wake without user interaction but are device-bound and never synced
/// to iCloud Keychain.
///
/// Pass a unique `service` string to isolate items (e.g., per test run).
public actor KeychainCredentialStore: CredentialStore {
    private let service: String

    public init(service: String = "com.stevedore.credentials") {
        self.service = service
    }

    public func store(_ credential: Credential, for hostID: RemoteHostDescriptor.ID) async throws {
        let data = try JSONEncoder().encode(credential)
        do {
            try KeychainQuery.add(service: self.service, account: hostID.uuidString, data: data)
        } catch KeychainQuery.KeychainError.duplicateItem {
            try KeychainQuery.update(service: self.service, account: hostID.uuidString, data: data)
        }
    }

    public func credential(for hostID: RemoteHostDescriptor.ID) async throws -> Credential? {
        do {
            let data = try KeychainQuery.fetch(service: self.service, account: hostID.uuidString)
            return try JSONDecoder().decode(Credential.self, from: data)
        } catch CredentialError.notFound {
            return nil
        } catch is DecodingError {
            throw CredentialError.storageFailure(detail: "Credential data could not be decoded")
        }
    }

    public func remove(for hostID: RemoteHostDescriptor.ID) async throws {
        try KeychainQuery.delete(service: self.service, account: hostID.uuidString)
    }

    public func list() async throws -> [RemoteHostDescriptor.ID] {
        let accounts = try KeychainQuery.listAccounts(service: self.service)
        return accounts.compactMap { UUID(uuidString: $0) }
    }
}
