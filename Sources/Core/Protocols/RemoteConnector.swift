/// Opens or tests a remote session for a given host descriptor.
///
/// `open(_:credential:)` returns a fully usable `FileSystemProvider`; the
/// connector hides the protocol-specific session lifecycle (reconnect,
/// pooling, keepalive) behind that abstraction.
public protocol RemoteConnector: Sendable {
    func test(
        _ host: RemoteHostDescriptor,
        credential: Credential?
    ) async throws -> ConnectionTestResult

    func open(
        _ host: RemoteHostDescriptor,
        credential: Credential?
    ) async throws -> any FileSystemProvider
}
