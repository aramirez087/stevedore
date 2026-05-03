import Core
import Foundation

// MARK: - OperationState

/// Lifecycle states of a queued file operation.
///
/// Lifted to top-level to satisfy SwiftLint's `nesting` rule.
public enum OperationState: Sendable {
    case pending
    case active
    case paused
    case completed(OperationResult)
    case failed(any Error)
    case cancelled
}

// MARK: - Operation

/// Value-typed snapshot of a queued file operation.
///
/// The `FileOperationQueue` actor is the authoritative owner; all mutations
/// happen there. Copies emitted to subscribers are cheap because `Operation`
/// is a struct.
public struct Operation: Sendable, Identifiable {
    public typealias ID = OperationDescriptor.ID

    public let id: ID
    public let descriptor: OperationDescriptor
    public internal(set) var state: OperationState
    public internal(set) var progress: TransferProgress

    public init(descriptor: OperationDescriptor) {
        self.id = descriptor.id
        self.descriptor = descriptor
        self.state = .pending
        self.progress = TransferProgress(operationID: descriptor.id)
    }
}
