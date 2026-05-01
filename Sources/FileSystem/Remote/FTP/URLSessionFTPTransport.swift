import Core
import Foundation

/// URLSession-backed FTP transport.
///
/// Passive mode is negotiated automatically by the macOS network stack.
/// EPSV for dual-stack hosts is also handled transparently by the OS.
///
/// Known limitation: URLSession FTP STOR (store/upload) is unreliable for
/// large files on macOS 14. Tests for upload use `FakeFTPTransport`.
public final class URLSessionFTPTransport: FTPTransport, Sendable {
    private let host: String
    private let port: Int
    private let auth: RemoteAuthStrategy
    private let session: URLSession

    public init(host: String, port: Int = 21, auth: RemoteAuthStrategy) {
        self.host = host
        self.port = port
        self.auth = auth
        self.session = URLSession(configuration: .default)
    }

    public func connect() async throws {
        // URLSession connects lazily; this is a no-op for the MVP.
    }

    public func list(at path: String) async throws -> Data {
        let url = try ftpURL(path: path)
        let request = URLRequest(url: url)
        let (data, _) = try await session.data(for: request)
        return data
    }

    public func mlsd(at path: String) async throws -> Data {
        // URLSession does not support MLSD natively. Signal unsupported so
        // FTPProvider falls back to LIST.
        throw StevedoreError.unsupported("MLSD not available via URLSession")
    }

    public func retrieve(at path: String) -> AsyncThrowingStream<Data, any Error> {
        let ftpURL = try? self.ftpURL(path: path)
        let session = self.session
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = ftpURL else {
                        throw StevedoreError.invalidArgument("Invalid FTP path: \(path)")
                    }
                    let request = URLRequest(url: url)
                    let (data, _) = try await session.data(for: request)
                    continuation.yield(data)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func store(at path: String, data: AsyncThrowingStream<Data, any Error>) async throws {
        var body = Data()
        for try await chunk in data {
            body.append(chunk)
        }
        let url = try ftpURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "STOR"
        _ = try await self.session.upload(for: request, from: body)
    }

    public func makeDirectory(at path: String) async throws {
        throw StevedoreError.unsupported("MKD not available via URLSession FTP")
    }

    public func rename(from: String, to: String) async throws {
        throw StevedoreError.unsupported("RNFR/RNTO not available via URLSession FTP")
    }

    public func delete(at path: String) async throws {
        let url = try ftpURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELE"
        _ = try await self.session.data(for: request)
    }

    public func disconnect() async {
        self.session.invalidateAndCancel()
    }

    // MARK: - Helpers

    private func ftpURL(path: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "ftp"
        components.host = self.host
        components.port = self.port
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        if case .password(let user, let pass) = auth {
            components.user = user
            components.password = pass
        }
        guard let url = components.url else {
            throw StevedoreError.invalidArgument("Cannot build FTP URL for path: \(path)")
        }
        return url
    }
}
