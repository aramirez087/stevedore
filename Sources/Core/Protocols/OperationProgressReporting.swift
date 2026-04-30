/// Receives progress callbacks from a long-running operation.
///
/// Conformers should be cheap to call — typical implementations append to an
/// `AsyncStream` or update an `@Observable` view-model. Reports are advisory:
/// dropping one is safe but losing all of them is not.
public protocol OperationProgressReporting: Sendable {
    func report(_ progress: Progress) async
}
