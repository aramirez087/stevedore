import Core
import CryptoKit
import Foundation

// MARK: - SyncReadableProvider

/// Extends `FileSystemProvider` with chunked content reading for deep hash comparison.
///
/// Defined in `FeaturesSync` (not `FeaturesOperations`) to avoid cross-module coupling.
/// Providers conform independently; UI wires both conformances together at integration time.
public protocol SyncReadableProvider: FileSystemProvider {
    /// Produce a stream of fixed-size chunks from the file at `path`.
    func readChunks(
        at path: FilePath,
        chunkSize: Int
    ) -> AsyncThrowingStream<Data, any Error>
}

// MARK: - HashStrategy

/// Utilities for content-based file comparison.
public enum HashStrategy {
    public static let defaultChunkSize: Int = 256 * 1024 // 256 KB

    /// Computes a streaming SHA-256 digest from `stream`.
    ///
    /// Calls `Task.checkCancellation()` between chunks so parent-task
    /// cancellation halts the hash mid-stream.
    public static func sha256(
        reading stream: AsyncThrowingStream<Data, any Error>
    ) async throws -> SHA256Digest {
        var hasher = SHA256()
        for try await chunk in stream {
            try Task.checkCancellation()
            hasher.update(data: chunk)
        }
        // Check again after the loop: the stream may have terminated early because
        // the parent task was cancelled (next() returns nil rather than throwing).
        try Task.checkCancellation()
        return hasher.finalize()
    }
}
