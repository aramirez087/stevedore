import Core
import Foundation

// MARK: - DifferenceStatus

/// Describes how a file or directory differs between two sync roots.
public enum DifferenceStatus: Sendable, Hashable, Codable {
    case matched
    case modified
    case leftOnly
    case rightOnly
}

// MARK: - Difference

/// A single row in the folder comparison result.
///
/// `relativePath` uses the left root's scheme as a convention; its components
/// are relative to either root (e.g., `["src", "foo.swift"]`).
public struct Difference: Sendable, Identifiable {
    public typealias ID = UUID

    public let id: ID
    public let relativePath: FilePath
    public let status: DifferenceStatus
    /// `nil` when `status == .rightOnly`.
    public let leftItem: FileItem?
    /// `nil` when `status == .leftOnly`.
    public let rightItem: FileItem?

    public init(
        id: ID = UUID(),
        relativePath: FilePath,
        status: DifferenceStatus,
        leftItem: FileItem?,
        rightItem: FileItem?
    ) {
        self.id = id
        self.relativePath = relativePath
        self.status = status
        self.leftItem = leftItem
        self.rightItem = rightItem
    }
}
