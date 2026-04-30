/// Persistent secret store keyed by `RemoteHostDescriptor.ID`.
///
/// The production implementation lives in `ServicesCredentials` and bridges to
/// the macOS Keychain. Tests use `InMemoryCredentialStore`.
public protocol CredentialStore: Sendable {
    func store(_ credential: Credential, for hostID: RemoteHostDescriptor.ID) async throws
    func credential(for hostID: RemoteHostDescriptor.ID) async throws -> Credential?
    func remove(for hostID: RemoteHostDescriptor.ID) async throws
    func list() async throws -> [RemoteHostDescriptor.ID]
}
