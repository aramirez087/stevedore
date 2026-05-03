import Core

/// Describes a single conflict that would arise if an operation ran with
/// `ConflictPolicy.ask`. Returned by `LocalFileSystemProvider.detectConflicts(for:)`.
public struct ConflictDescriptor: Hashable, Sendable {
    /// Why the conflict was detected.
    public enum Reason: Hashable, Sendable {
        case destinationExists
        case destinationIsDirectory
        case destinationReadOnly
        case crossDeviceMove
    }

    public let source: FilePath
    public let destination: FilePath
    public let reason: Reason
    public let operationKind: OperationKind
}
