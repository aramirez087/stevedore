import Foundation

/// Simple `CredentialStore` backed by a dictionary. Safe to use in tests on
/// any actor; not suitable for production (no encryption, no persistence).
public actor InMemoryCredentialStore: CredentialStore {
    private var storage: [RemoteHostDescriptor.ID: Credential] = [:]

    public init() {}

    public func store(_ credential: Credential, for hostID: RemoteHostDescriptor.ID) async throws {
        self.storage[hostID] = credential
    }

    public func credential(for hostID: RemoteHostDescriptor.ID) async throws -> Credential? {
        self.storage[hostID]
    }

    public func remove(for hostID: RemoteHostDescriptor.ID) async throws {
        self.storage.removeValue(forKey: hostID)
    }

    public func list() async throws -> [RemoteHostDescriptor.ID] {
        Array(self.storage.keys)
    }

    /// Drops all stored credentials. Test-only helper.
    public func reset() {
        self.storage.removeAll()
    }
}
