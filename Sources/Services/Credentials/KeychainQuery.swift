import Core
import Foundation
import Security

/// Low-level, synchronous wrapper around `Security.framework` `SecItem*` APIs.
///
/// All queries use `kSecClassGenericPassword` and omit `kSecAttrSynchronizable`
/// so that items are device-local and never synced to iCloud Keychain.
/// Error descriptions include only the numeric `OSStatus`; secret payload is
/// never embedded in any error value.
enum KeychainQuery {
    // MARK: - Internal coordination error

    enum KeychainError: Error {
        case duplicateItem
    }

    // MARK: - Operations

    static func add(service: String, account: String, data: Data) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            throw KeychainError.duplicateItem
        }
        guard status == errSecSuccess else {
            throw self.mapStatus(status)
        }
    }

    static func fetch(service: String, account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw self.mapStatus(status)
        }
        guard let data = result as? Data else {
            throw CredentialError.storageFailure(detail: "Unexpected keychain data format")
        }
        return data
    }

    static func update(service: String, account: String, data: Data) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: data,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw self.mapStatus(status)
        }
    }

    static func delete(service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw self.mapStatus(status)
        }
    }

    static func listAccounts(service: String) throws -> [String] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw self.mapStatus(status)
        }
        guard let items = result as? [[String: Any]] else {
            return []
        }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    // MARK: - Error mapping

    private static func mapStatus(_ status: OSStatus) -> CredentialError {
        switch status {
        case errSecItemNotFound:
            .notFound
        default:
            .storageFailure(detail: "OSStatus \(status)")
        }
    }
}
