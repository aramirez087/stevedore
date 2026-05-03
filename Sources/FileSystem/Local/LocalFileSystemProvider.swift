import Core
import Foundation

/// Actor-based `FileSystemProvider` for the local macOS filesystem.
///
/// Concurrency contract:
/// - `enumerate` and `watch` are `nonisolated`; they return stream handles
///   synchronously so callers never await actor isolation just to begin
///   iteration.
/// - `attributes` and `execute` are actor-isolated. Blocking `FileManager`
///   calls are funnelled through `Task.detached` so they never pin the actor
///   executor and cancellation propagates naturally.
/// - Actor reentrancy: `execute` may suspend at `Task.detached` boundaries;
///   callers must not assume serialised ordering across concurrent `execute`
///   invocations.
public actor LocalFileSystemProvider: FileSystemProvider {
    public nonisolated let scheme: ConnectionScheme = .local

    private let watcher: FSEventsWatcher
    private let operations: LocalFileOperations

    public init() {
        self.watcher = FSEventsWatcher()
        self.operations = LocalFileOperations()
    }

    // MARK: - FileSystemProvider

    public func attributes(at path: FilePath) async throws -> FileAttributes {
        guard path.scheme == .local else {
            throw StevedoreError.invalidArgument(
                "LocalFileSystemProvider received non-local FilePath: \(path.scheme)"
            )
        }
        let url = URL(fileURLWithPath: path.posixString)
        return try await Task.detached(priority: .userInitiated) {
            try Self.readAttributes(url: url)
        }.value
    }

    public nonisolated func enumerate(
        at path: FilePath,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        guard path.scheme == .local else {
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: StevedoreError.invalidArgument(
                        "LocalFileSystemProvider received non-local FilePath: \(path.scheme)"
                    )
                )
            }
        }
        let directoryURL = URL(fileURLWithPath: path.posixString, isDirectory: true)
        return LocalDirectoryEnumerator.stream(at: directoryURL, options: options)
    }

    public func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        try await self.operations.perform(operation, progress: progress)
    }

    public nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        self.watcher.events(for: path, recursive: true)
    }

    // MARK: - Conflict detection

    /// Preflight: enumerate conflicts that would arise if `op` ran with
    /// `ConflictPolicy.ask`. Cheap to call — no I/O beyond `stat`.
    public func detectConflicts(for op: OperationDescriptor) async -> [ConflictDescriptor] {
        await self.operations.detectConflicts(for: op)
    }

    // MARK: - Private helpers

    private static func readAttributes(url: URL) throws -> FileAttributes {
        do {
            let values = try url.resourceValues(forKeys: URLResourceMapperKeys)
            let kind = URLResourceMapper.fileKind(values: values)
            return URLResourceMapper.fileAttributes(url: url, values: values, kind: kind)
        } catch let nsError as NSError {
            let path = FilePath(scheme: .local, posix: url.path)
            switch nsError.code {
            case NSFileReadNoSuchFileError, NSFileNoSuchFileError:
                throw StevedoreError.fileSystem(.notFound(path))
            case NSFileReadNoPermissionError:
                throw StevedoreError.fileSystem(.permissionDenied(path))
            default:
                throw StevedoreError.fileSystem(.ioFailure(detail: nsError.localizedDescription))
            }
        }
    }
}
