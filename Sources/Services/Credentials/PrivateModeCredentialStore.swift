import Core

/// Ephemeral in-memory `CredentialStore` for private-mode browsing sessions.
///
/// All credentials are cleared when the actor is deallocated (i.e., when the
/// private browsing session ends). Nothing is persisted between app launches.
public actor PrivateModeCredentialStore: CredentialStore {
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

    /// Immediately clears all stored credentials.
    public func reset() {
        self.storage.removeAll()
    }
}
