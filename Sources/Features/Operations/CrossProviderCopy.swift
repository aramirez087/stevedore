import Core
import Foundation

// MARK: - DataReadableProvider

/// A `FileSystemProvider` that can stream file data as chunks.
///
/// Providers that support cross-provider copies must conform to this protocol.
/// Local and remote providers add conformance in their own sessions.
public protocol DataReadableProvider: FileSystemProvider {
    /// Returns file data as a stream of chunks. The `chunkSize` is advisory;
    /// providers may return smaller chunks (e.g., network buffers).
    func read(
        at path: FilePath,
        chunkSize: Int
    ) -> AsyncThrowingStream<Data, any Error>
}

// MARK: - DataWritableProvider

/// A `FileSystemProvider` that can receive chunked writes for cross-provider copies.
public protocol DataWritableProvider: FileSystemProvider {
    /// Write a chunk to the destination.
    ///
    /// - Parameters:
    ///   - data: Chunk bytes.
    ///   - destination: Target path.
    ///   - isFirst: When `true`, the provider creates (or truncates) the file.
    ///   - isLast: When `true`, the provider flushes and closes the file handle.
    func writeChunk(
        _ data: Data,
        to destination: FilePath,
        isFirst: Bool,
        isLast: Bool
    ) async throws

    /// Remove a partially-written file. Called on cancellation or I/O errors
    /// to ensure no half-written files survive.
    func deletePartial(at path: FilePath) async throws
}

// MARK: - PauseResumeGate

/// Actor-based pause/resume checkpoint for long-running async loops.
///
/// Chunk-copy loops call `checkPoint()` before each write. When paused,
/// the call suspends via `CheckedContinuation` until `resume()` is called.
/// This avoids `DispatchSemaphore.wait()` which is banned in async contexts.
public actor PauseResumeGate {
    private var suspended: Bool = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    /// Suspend if paused; return immediately otherwise.
    public func checkPoint() async {
        guard self.suspended else { return }
        await withCheckedContinuation { continuation in
            self.waiters.append(continuation)
        }
    }

    /// Pause future `checkPoint()` callers.
    public func pause() {
        self.suspended = true
    }

    /// Resume all suspended callers.
    public func resume() {
        self.suspended = false
        let pending = self.waiters
        self.waiters = []
        for continuation in pending {
            continuation.resume()
        }
    }
}

// MARK: - CrossProviderCopy

/// Copies a single file between two providers that may use different schemes.
///
/// Data is streamed in `chunkSize`-byte windows. Each iteration:
///   1. Checks `Task.isCancelled`.
///   2. Awaits the `PauseResumeGate` checkpoint (pause/resume).
///   3. Writes the chunk to the destination provider.
///
/// On any error (including `CancellationError`) the partial destination file
/// is deleted via `DataWritableProvider.deletePartial(at:)`.
public struct CrossProviderCopy: Sendable {
    public static let defaultChunkSize: Int = 256 * 1024 // 256 KB

    public let chunkSize: Int

    public init(chunkSize: Int = defaultChunkSize) {
        self.chunkSize = chunkSize
    }

    // swiftlint:disable function_parameter_count
    /// Copy `source` on `sourceProvider` to `destination` on `destProvider`.
    ///
    /// Returns the total number of bytes copied.
    public func copy(
        from source: FilePath,
        on sourceProvider: any DataReadableProvider,
        to destination: FilePath,
        on destProvider: any DataWritableProvider,
        gate: PauseResumeGate,
        progress: (any OperationProgressReporting)?
    ) async throws -> Int64 {
        var bytesCopied: Int64 = 0
        var isFirst = true
        // One-element look-ahead so we can detect the last chunk without an
        // extra read call.
        var lookahead: Data?
        var iterator = sourceProvider.read(at: source, chunkSize: self.chunkSize).makeAsyncIterator()

        // Prime the lookahead.
        lookahead = try await iterator.next()

        do {
            while let current = lookahead {
                try Task.checkCancellation()
                await gate.checkPoint()

                // Peek at the next chunk to know whether `current` is last.
                let next = try await iterator.next()
                let isLast = next == nil

                try await destProvider.writeChunk(
                    current,
                    to: destination,
                    isFirst: isFirst,
                    isLast: isLast
                )
                bytesCopied += Int64(current.count)
                isFirst = false

                if let reporter = progress {
                    let snapshot = Progress(
                        bytesDone: bytesCopied,
                        bytesTotal: nil,
                        phase: isLast ? .completed : .transferring,
                        throughputBytesPerSecond: nil,
                        currentItemDisplayName: source.lastComponent
                    )
                    await reporter.report(snapshot)
                }

                lookahead = next
            }
        } catch {
            try? await destProvider.deletePartial(at: destination)
            throw error
        }

        return bytesCopied
    }

    // swiftlint:enable function_parameter_count
}
