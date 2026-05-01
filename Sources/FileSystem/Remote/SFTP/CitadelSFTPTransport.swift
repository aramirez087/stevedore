import Citadel
import Core
import Crypto
import Foundation
import NIO

/// Concrete SFTP transport backed by the Citadel library.
///
/// All Citadel-specific API calls are isolated here. If Citadel's method
/// signatures change, only this file needs updating.
///
/// Host-key validation uses `.acceptAnything()` for the MVP. Production
/// deployments should supply a trust-store-backed validator.
///
/// Thread safety: `SFTPClient` is `Sendable` and handles its own concurrency.
/// This class holds only `Sendable` state, so it is safe to share across tasks.
public final class CitadelSFTPTransport: SFTPTransport, @unchecked Sendable {
    // @unchecked Sendable: sftp is SFTPClient (Sendable), sshClient is SSHClient (final class,
    // all operations are async on the event loop — we hold it only to keep the session alive).
    private let sftp: SFTPClient
    private let sshClient: SSHClient

    private init(sftp: SFTPClient, sshClient: SSHClient) {
        self.sftp = sftp
        self.sshClient = sshClient
    }

    /// Connect to `host:port`, authenticate with `auth`, and open an SFTP channel.
    public static func connect(
        host: String,
        port: Int,
        auth: RemoteAuthStrategy
    ) async throws -> CitadelSFTPTransport {
        // SSHAuthenticationMethod is not Sendable in Citadel (pre-concurrency library).
        // We box it so the @Sendable factory closure can capture it safely. The value is
        // created once here and read once during the SSH handshake on the NIO event loop.
        let authBox = try UncheckedSendableBox(value: makeAuthMethod(auth: auth))
        let settings = SSHClientSettings(
            host: host,
            port: port,
            authenticationMethod: { authBox.value },
            hostKeyValidator: .acceptAnything()
        )
        let sshClient = try await SSHClient.connect(to: settings)
        let sftp = try await sshClient.openSFTP()
        return CitadelSFTPTransport(sftp: sftp, sshClient: sshClient)
    }

    // MARK: - SFTPTransport

    public func listDirectory(at path: String) async throws -> [SFTPEntry] {
        do {
            let names = try await sftp.listDirectory(atPath: path)
            return names.flatMap { name in
                name.components.compactMap { component -> SFTPEntry? in
                    guard component.filename != ".", component.filename != ".." else { return nil }
                    let fullPath = path == "/" ? "/\(component.filename)" : "\(path)/\(component.filename)"
                    return SFTPEntry(
                        name: component.filename,
                        posixPath: fullPath,
                        isDirectory: self.isDirectory(permissions: component.attributes.permissions),
                        isSymlink: self.isSymlink(permissions: component.attributes.permissions),
                        sizeInBytes: component.attributes.size.map { Int64($0) },
                        permissions: component.attributes.permissions,
                        modificationDate: component.attributes.accessModificationTime?.modificationTime
                    )
                }
            }
        } catch {
            throw self.mapError(error)
        }
    }

    public func stat(at path: String) async throws -> SFTPEntry {
        do {
            let attrs = try await sftp.getAttributes(at: path)
            let name = path.split(separator: "/").last.map(String.init) ?? path
            return SFTPEntry(
                name: name,
                posixPath: path,
                isDirectory: self.isDirectory(permissions: attrs.permissions),
                isSymlink: self.isSymlink(permissions: attrs.permissions),
                sizeInBytes: attrs.size.map { Int64($0) },
                permissions: attrs.permissions,
                modificationDate: attrs.accessModificationTime?.modificationTime
            )
        } catch {
            throw self.mapError(error)
        }
    }

    public func createDirectory(at path: String) async throws {
        do {
            try await self.sftp.createDirectory(atPath: path)
        } catch {
            throw self.mapError(error)
        }
    }

    public func rename(from source: String, to destination: String) async throws {
        do {
            try await self.sftp.rename(at: source, to: destination)
        } catch {
            throw self.mapError(error)
        }
    }

    public func remove(at path: String) async throws {
        do {
            do {
                try await self.sftp.remove(at: path)
            } catch {
                try await self.sftp.rmdir(at: path)
            }
        } catch {
            throw self.mapError(error)
        }
    }

    public func readFile(at path: String, fromOffset offset: UInt64) -> AsyncThrowingStream<Data, any Error> {
        let sftp = self.sftp
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let file = try await sftp.openFile(filePath: path, flags: .read)
                    var currentOffset = offset
                    let chunkSize: UInt32 = 32768
                    while true {
                        try Task.checkCancellation()
                        let buffer = try await file.read(from: currentOffset, length: chunkSize)
                        if buffer.readableBytes == 0 {
                            try await file.close()
                            continuation.finish()
                            return
                        }
                        currentOffset += UInt64(buffer.readableBytes)
                        continuation.yield(Data(buffer.readableBytesView))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func writeFile(at path: String, data: AsyncThrowingStream<Data, any Error>) async throws {
        do {
            let file = try await sftp.openFile(
                filePath: path,
                flags: [.write, .create, .truncate]
            )
            var offset: UInt64 = 0
            for try await chunk in data {
                try Task.checkCancellation()
                let buffer = ByteBuffer(bytes: chunk)
                try await file.write(buffer, at: offset)
                offset += UInt64(chunk.count)
            }
            try await file.close()
        } catch {
            throw self.mapError(error)
        }
    }

    public func chmod(at path: String, permissions: UInt32) async throws {
        do {
            var attrs = SFTPFileAttributes()
            attrs.permissions = permissions
            try await self.sftp.setAttributes(at: path, to: attrs)
        } catch {
            throw self.mapError(error)
        }
    }

    // MARK: - Helpers

    private func isDirectory(permissions: UInt32?) -> Bool {
        guard let p = permissions else { return false }
        return (p & 0o170000) == 0o040000
    }

    private func isSymlink(permissions: UInt32?) -> Bool {
        guard let p = permissions else { return false }
        return (p & 0o170000) == 0o120000
    }

    private func mapError(_ error: any Error) -> any Error {
        if let stevedoreError = error as? StevedoreError { return stevedoreError }
        let detail = error.localizedDescription
        if detail.lowercased().contains("auth") || detail.lowercased().contains("permission") {
            return StevedoreError.remote(.authenticationFailed)
        }
        return StevedoreError.remote(.connectionFailed(detail: detail))
    }
}

// MARK: - Auth mapping

private func makeAuthMethod(auth: RemoteAuthStrategy) throws -> SSHAuthenticationMethod {
    switch auth {
    case .password(let username, let password):
        return .passwordBased(username: username, password: password)
    case .privateKey(let username, let pem, _):
        // Parse raw 32-byte Ed25519 private key from base64-encoded PEM body.
        // Full OpenSSH format parsing is not implemented in this session.
        guard let keyData = extractPEMBytes(pem: pem), keyData.count >= 32 else {
            throw StevedoreError.remote(.authenticationFailed)
        }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(keyData.prefix(32)))
        return .ed25519(username: username, privateKey: privateKey)
    case .anonymous:
        return .passwordBased(username: "anonymous", password: "anonymous@")
    default:
        throw StevedoreError.remote(.authenticationFailed)
    }
}

private func extractPEMBytes(pem: String) -> [UInt8]? {
    let base64 = pem.components(separatedBy: "\n")
        .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        .joined()
    return Data(base64Encoded: base64).map { [UInt8]($0) }
}

/// Crosses the Sendable boundary for values from pre-Swift-6 libraries.
/// Safe here because `UncheckedSendableBox` is created and consumed synchronously
/// with no actual cross-thread mutation.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
}
