import Foundation

public extension Result {
    /// Maps the failure type to a different error type.
    func mapErrorTo<NewFailure: Error>(
        _ transform: (Failure) -> NewFailure
    ) -> Result<Success, NewFailure> {
        switch self {
        case .success(let value): .success(value)
        case .failure(let error): .failure(transform(error))
        }
    }

    /// Await-able flat-map on the success branch; failure passes through unchanged.
    func asyncFlatMap<NewSuccess>(
        _ transform: (Success) async -> Result<NewSuccess, Failure>
    ) async -> Result<NewSuccess, Failure> {
        switch self {
        case .success(let value): await transform(value)
        case .failure(let error): .failure(error)
        }
    }
}

public extension Result where Failure == any Error {
    /// Converts to `Result<Success, StevedoreError>` via `StevedoreErrorBridge`.
    func toStevedoreError() -> Result<Success, StevedoreError> {
        self.mapErrorTo { StevedoreErrorBridge.map($0) }
    }
}

/// Bridges arbitrary `Error` values to `StevedoreError`.
///
/// Lives in Sources/Core/Utilities/ to stay within the session touch-glob —
/// adding a static func to StevedoreError would touch Sources/Core/Errors/.
public enum StevedoreErrorBridge {
    /// Mapping rules (applied in order):
    /// 1. Already a `StevedoreError` → returned unchanged.
    /// 2. `CancellationError` → `.cancelled`.
    /// 3. Anything else → `.invalidArgument(localizedDescription)`.
    public static func map(_ error: any Error) -> StevedoreError {
        if let stevedore = error as? StevedoreError {
            return stevedore
        }
        if error is CancellationError {
            return .cancelled
        }
        return .invalidArgument(error.localizedDescription)
    }
}
