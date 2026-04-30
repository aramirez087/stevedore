/// Primitive operation runner.
///
/// The operations engine (Session 04) decomposes high-level user intents into
/// a sequence of `OperationDescriptor`s and forwards them here. Concrete
/// providers implement this protocol — the queue stays provider-agnostic.
public protocol FileOperationExecutor: Sendable {
    func perform(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult
}
