import Foundation

/// Describes a remote endpoint sufficient to attempt a connection.
///
/// Note: secrets (passwords, key material) live in `Credential` and are looked
/// up via `CredentialStore` keyed on `RemoteHostDescriptor.ID`. The descriptor
/// itself is safe to serialize — for example, in the bookmark bar.
public struct RemoteHostDescriptor: Hashable, Sendable, Codable, Identifiable {
    public typealias ID = UUID

    public let id: ID
    public let displayName: String
    public let scheme: ConnectionScheme
    public let host: String
    public let port: Int?
    public let username: String?
    public let initialPath: FilePath?

    public init(
        id: ID = UUID(),
        displayName: String,
        scheme: ConnectionScheme,
        host: String,
        port: Int? = nil,
        username: String? = nil,
        initialPath: FilePath? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.scheme = scheme
        self.host = host
        self.port = port
        self.username = username
        self.initialPath = initialPath
    }
}

/// Outcome of `RemoteConnector.test(_:credential:)`. Carries diagnostic detail
/// without surfacing protocol-specific errors to the UI directly.
public struct ConnectionTestResult: Hashable, Sendable, Codable {
    public enum Status: String, Codable, Sendable, Hashable, CaseIterable {
        case success
        case authenticationFailed
        case unreachable
        case timeout
        case unsupported
        case unknown
    }

    public let status: Status
    public let latencyMilliseconds: Int?
    public let serverBanner: String?

    public init(status: Status, latencyMilliseconds: Int? = nil, serverBanner: String? = nil) {
        self.status = status
        self.latencyMilliseconds = latencyMilliseconds
        self.serverBanner = serverBanner
    }
}
