/// Root abstraction for any file source — local disk, remote SFTP/FTP/S3,
/// or an archive opened as a virtual filesystem.
///
/// All methods are async; callers should treat them as cancellable. Watch is
/// expressed as an `AsyncStream` rather than delegate notification so cancel-
/// lation is uniform across providers.
public protocol FileSystemProvider: Sendable {
    /// The scheme this provider serves. Constant for the lifetime of the
    /// instance.
    var scheme: ConnectionScheme { get }

    /// Fetch attributes for a single path.
    func attributes(at path: FilePath) async throws -> FileAttributes

    /// Open an enumeration at a given path. The returned stream is throwing
    /// and lazy: iteration begins the actual work and any provider error
    /// surfaces through `next()`.
    func enumerate(at path: FilePath, options: EnumerationOptions) -> AsyncThrowingStream<FileItem, any Error>

    /// Execute a single operation in the context of this provider.
    func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult

    /// Stream of changes observed under `path`. The stream terminates when
    /// observation is cancelled (e.g., by deinitializing the iterator).
    func watch(_ path: FilePath) -> AsyncStream<FilePathChange>
}
