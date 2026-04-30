import Foundation

/// Fully describes a single file operation that can be queued and executed.
///
/// Identifiable so the transfers UI can diff queue contents. Codable so the
/// queue can be persisted across launches (downstream session 21).
public struct OperationDescriptor: Hashable, Sendable, Codable, Identifiable {
    public typealias ID = UUID

    public let id: ID
    public let kind: OperationKind
    public let sources: [FilePath]
    public let destination: FilePath?
    public let conflictPolicy: ConflictPolicy
    public let createdAt: Date

    public init(
        id: ID = UUID(),
        kind: OperationKind,
        sources: [FilePath],
        destination: FilePath? = nil,
        conflictPolicy: ConflictPolicy = .ask,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.sources = sources
        self.destination = destination
        self.conflictPolicy = conflictPolicy
        self.createdAt = createdAt
    }
}

/// Outcome reported by `FileOperationExecutor` and provider implementations.
public struct OperationResult: Hashable, Sendable, Codable {
    public enum Status: String, Codable, Sendable, Hashable, CaseIterable {
        case completed
        case skipped
        case cancelled
        case partiallyFailed
    }

    public let descriptorID: OperationDescriptor.ID
    public let status: Status
    public let bytesProcessed: Int64
    public let itemsProcessed: Int

    public init(
        descriptorID: OperationDescriptor.ID,
        status: Status,
        bytesProcessed: Int64,
        itemsProcessed: Int
    ) {
        self.descriptorID = descriptorID
        self.status = status
        self.bytesProcessed = bytesProcessed
        self.itemsProcessed = itemsProcessed
    }
}

/// A single mutation observed under a watched path.
public struct FilePathChange: Hashable, Sendable, Codable {
    public enum Kind: String, Codable, Sendable, Hashable, CaseIterable {
        case created
        case modified
        case deleted
        case renamed
    }

    public let path: FilePath
    public let kind: Kind

    public init(path: FilePath, kind: Kind) {
        self.path = path
        self.kind = kind
    }
}

/// Options governing a directory enumeration.
public struct EnumerationOptions: Hashable, Sendable, Codable {
    public let includesHiddenFiles: Bool
    public let isRecursive: Bool
    public let followsSymbolicLinks: Bool

    public init(
        includesHiddenFiles: Bool = false,
        isRecursive: Bool = false,
        followsSymbolicLinks: Bool = false
    ) {
        self.includesHiddenFiles = includesHiddenFiles
        self.isRecursive = isRecursive
        self.followsSymbolicLinks = followsSymbolicLinks
    }

    public static let `default` = Self()
}
