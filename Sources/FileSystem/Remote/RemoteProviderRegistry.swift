import Core
import Foundation

/// Maps `ConnectionScheme` values to provider factories and opens remote
/// `FileSystemProvider` instances on demand.
///
/// Conforms to `RemoteConnector` so the UI and operation engine can treat it
/// as the single point of remote volume access.
///
/// Inject custom factories in tests:
/// ```swift
/// await registry.register(scheme: .sftp) { host, credential in
///     SFTPProvider(descriptor: host, session: RemoteSession { FakeSFTPTransport() })
/// }
/// ```
public actor RemoteProviderRegistry: RemoteConnector {
    public typealias Factory = @Sendable (
        RemoteHostDescriptor,
        Credential?
    ) async throws -> any FileSystemProvider

    private var factories: [ConnectionScheme: Factory]

    public init(factories: [ConnectionScheme: Factory] = [:]) {
        self.factories = factories
    }

    /// Register (or replace) the factory for a given scheme.
    public func register(scheme: ConnectionScheme, factory: @escaping Factory) {
        self.factories[scheme] = factory
    }

    // MARK: - RemoteConnector

    public func open(
        _ host: RemoteHostDescriptor,
        credential: Credential?
    ) async throws -> any FileSystemProvider {
        guard let factory = factories[host.scheme] else {
            throw StevedoreError.unsupported("No provider registered for scheme: \(host.scheme.rawValue)")
        }
        return try await factory(host, credential)
    }

    public func test(
        _ host: RemoteHostDescriptor,
        credential: Credential?
    ) async throws -> ConnectionTestResult {
        let start = Date()
        do {
            let provider = try await open(host, credential: credential)
            let rootPath = host.initialPath ?? FilePath.root(host.scheme)
            _ = try await provider.attributes(at: rootPath)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return ConnectionTestResult(status: .success, latencyMilliseconds: latency)
        } catch let error as StevedoreError {
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            switch error {
            case .remote(let remoteError):
                switch remoteError {
                case .authenticationFailed:
                    return ConnectionTestResult(status: .authenticationFailed, latencyMilliseconds: latency)
                case .connectionFailed, .timeout:
                    return ConnectionTestResult(status: .unreachable, latencyMilliseconds: latency)
                case .protocolMismatch:
                    return ConnectionTestResult(status: .unsupported, latencyMilliseconds: latency)
                }
            case .unsupported:
                return ConnectionTestResult(status: .unsupported, latencyMilliseconds: latency)
            default:
                return ConnectionTestResult(status: .unknown, latencyMilliseconds: latency)
            }
        } catch {
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return ConnectionTestResult(status: .unknown, latencyMilliseconds: latency)
        }
    }

    // MARK: - Default factory

    /// Returns a registry pre-wired with real transports for SFTP, FTP, WebDAV, and S3.
    /// `.local` and `.smb` are not registered (out of scope for this session).
    public static func makeDefault() -> RemoteProviderRegistry {
        RemoteProviderRegistry(factories: [
            .sftp: { host, credential in
                let auth = RemoteAuth.strategy(for: credential, host: host)
                let h = host.host
                let p = host.port ?? 22
                let session = RemoteSession<any SFTPTransport> {
                    try await CitadelSFTPTransport.connect(host: h, port: p, auth: auth)
                }
                return SFTPProvider(descriptor: host, session: session)
            },
            .ftp: { host, credential in
                let auth = RemoteAuth.strategy(for: credential, host: host)
                let h = host.host
                let p = host.port ?? 21
                let session = RemoteSession<any FTPTransport> {
                    let t = URLSessionFTPTransport(host: h, port: p, auth: auth)
                    try await t.connect()
                    return t
                }
                return FTPProvider(descriptor: host, session: session)
            },
            .webdav: { host, credential in
                let auth = RemoteAuth.strategy(for: credential, host: host)
                let scheme = "https"
                let port = host.port ?? 443
                guard let baseURL = URL(string: "\(scheme)://\(host.host):\(port)") else {
                    throw StevedoreError.invalidArgument("Invalid WebDAV host: \(host.host)")
                }
                let session = RemoteSession<any WebDAVTransport> {
                    URLSessionWebDAVTransport(baseURL: baseURL, auth: auth)
                }
                return WebDAVProvider(descriptor: host, session: session)
            },
            .s3: { host, credential in
                let region = Self.extractRegion(from: host.host)
                let auth = RemoteAuth.strategy(for: credential, host: host, region: region)
                let session = RemoteSession<any S3Transport> {
                    SotoS3Transport(auth: auth, region: region)
                }
                return S3Provider(descriptor: host, session: session)
            },
        ])
    }

    // MARK: - Helpers

    /// Extract AWS region from hostnames like `s3.us-east-1.amazonaws.com` or
    /// `bucket.s3.eu-west-1.amazonaws.com`. Falls back to `us-east-1`.
    private static func extractRegion(from host: String) -> String {
        let patterns = [
            #"s3\.([a-z0-9-]+)\.amazonaws\.com"#,
            #"\.s3\.([a-z0-9-]+)\.amazonaws\.com"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: host, range: NSRange(host.startIndex..., in: host)),
               let range = Range(match.range(at: 1), in: host) {
                return String(host[range])
            }
        }
        return "us-east-1"
    }
}
