import Core
import Foundation

// MARK: - SyncMode

/// Governs the direction and deletion behaviour of a sync operation.
public enum SyncMode: String, Sendable, Codable, Hashable, CaseIterable {
    case oneWayMirror // left → right; extras on right are deleted
    case oneWayContribute // left → right; extras on right are kept
    case twoWay // bidirectional; conflicts resolved by strategy
}

// MARK: - ConflictResolutionStrategy

/// How to resolve a file that was modified on both sides (two-way sync only).
public enum ConflictResolutionStrategy: String, Sendable, Codable, Hashable, CaseIterable {
    case newerWins // compare modificationDate; left wins on tie
    case largerWins // compare sizeInBytes;      left wins on tie
    case manual // surfaces via SyncEngine continuation per conflict
}

// MARK: - SyncOptions

/// Configures a folder comparison and sync operation.
public struct SyncOptions: Sendable {
    public let mode: SyncMode
    /// Glob patterns matched against relative POSIX paths. Matched items are excluded.
    public let ignoreGlobs: [String]
    /// Files with a size delta ≤ this value are considered equal in size.
    public let sizeTolerance: Int64
    /// Files with a mtime delta ≤ this value are considered equal in mtime.
    public let mtimeTolerance: TimeInterval
    public let conflictResolution: ConflictResolutionStrategy
    /// When `true`, SHA-256 content comparison is used instead of size+mtime.
    public let useDeepHash: Bool

    public static let `default` = Self()

    public init(
        mode: SyncMode = .oneWayMirror,
        ignoreGlobs: [String] = [],
        sizeTolerance: Int64 = 0,
        mtimeTolerance: TimeInterval = 0,
        conflictResolution: ConflictResolutionStrategy = .newerWins,
        useDeepHash: Bool = false
    ) {
        self.mode = mode
        self.ignoreGlobs = ignoreGlobs
        self.sizeTolerance = sizeTolerance
        self.mtimeTolerance = mtimeTolerance
        self.conflictResolution = conflictResolution
        self.useDeepHash = useDeepHash
    }
}
