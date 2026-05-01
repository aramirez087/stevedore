import Core
import Foundation

/// A single entry returned by an SFTP directory listing or stat.
public struct SFTPEntry: Sendable, Hashable {
    public let name: String
    public let posixPath: String
    public let isDirectory: Bool
    public let isSymlink: Bool
    public let symbolicLinkTarget: String?
    public let sizeInBytes: Int64?
    public let permissions: UInt32?
    public let modificationDate: Date?

    public init(
        name: String,
        posixPath: String,
        isDirectory: Bool,
        isSymlink: Bool = false,
        symbolicLinkTarget: String? = nil,
        sizeInBytes: Int64? = nil,
        permissions: UInt32? = nil,
        modificationDate: Date? = nil
    ) {
        self.name = name
        self.posixPath = posixPath
        self.isDirectory = isDirectory
        self.isSymlink = isSymlink
        self.symbolicLinkTarget = symbolicLinkTarget
        self.sizeInBytes = sizeInBytes
        self.permissions = permissions
        self.modificationDate = modificationDate
    }
}

/// Transport abstraction for SFTP. All Citadel-specific types stay in
/// `CitadelSFTPTransport`; fakes implement this protocol directly.
public protocol SFTPTransport: Sendable {
    func listDirectory(at path: String) async throws -> [SFTPEntry]
    func stat(at path: String) async throws -> SFTPEntry
    func createDirectory(at path: String) async throws
    func rename(from source: String, to destination: String) async throws
    func remove(at path: String) async throws
    func readFile(at path: String, fromOffset offset: UInt64) -> AsyncThrowingStream<Data, any Error>
    func writeFile(at path: String, data: AsyncThrowingStream<Data, any Error>) async throws
    func chmod(at path: String, permissions: UInt32) async throws
}
