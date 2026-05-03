import Core
import CryptoKit
import FeaturesSync
import Foundation
import XCTest

// MARK: - Fixture helpers

func fixtureItem(
    relPath: String,
    root: FilePath,
    kind: FileKind = .regularFile,
    size: Int64 = 1024,
    mtime: Date = Date(timeIntervalSince1970: 1_000_000)
) -> FileItem {
    let path = root.appending(posix: relPath)
    let attrs = FileAttributes(sizeInBytes: size, modificationDate: mtime)
    return FileItem(path: path, kind: kind, attributes: attrs)
}

// MARK: - InMemorySyncProvider

/// In-memory `SyncReadableProvider` backed by `[FilePath: Data]`.
/// Derives `FileItem` attributes (size + mtime) from stored data and a per-path mtime map.
final actor InMemorySyncProvider: SyncReadableProvider {
    nonisolated let scheme: ConnectionScheme
    private var store: [FilePath: Data] = [:]
    private var mtimes: [FilePath: Date] = [:]

    init(scheme: ConnectionScheme = .local) {
        self.scheme = scheme
    }

    func seed(_ data: Data, at path: FilePath, mtime: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.store[path] = data
        self.mtimes[path] = mtime
    }

    // MARK: FileSystemProvider

    func attributes(at path: FilePath) async throws -> FileAttributes {
        guard let data = self.store[path] else {
            throw StevedoreError.fileSystem(.notFound(path))
        }
        return FileAttributes(sizeInBytes: Int64(data.count), modificationDate: self.mtimes[path])
    }

    nonisolated func enumerate(
        at path: FilePath,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                let items = await self.items(under: path, recursive: options.isRecursive)
                for item in items {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }
                    continuation.yield(item)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        OperationResult(
            descriptorID: operation.id,
            status: .completed,
            bytesProcessed: 0,
            itemsProcessed: 0
        )
    }

    nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream { continuation in continuation.finish() }
    }

    // MARK: SyncReadableProvider

    nonisolated func readChunks(
        at path: FilePath,
        chunkSize: Int
    ) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                guard let data = await self.store[path] else {
                    continuation.finish(throwing: StevedoreError.fileSystem(.notFound(path)))
                    return
                }
                var offset = 0
                while offset < data.count {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }
                    let end = min(offset + chunkSize, data.count)
                    continuation.yield(data[offset ..< end])
                    offset = end
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Private

    private func items(under root: FilePath, recursive: Bool) -> [FileItem] {
        var result: [FileItem] = []
        for (path, data) in self.store {
            guard path.scheme == root.scheme else { continue }
            guard let rel = path.relative(to: root), !rel.isEmpty else { continue }
            if !recursive, rel.count > 1 { continue }
            let attrs = FileAttributes(
                sizeInBytes: Int64(data.count),
                modificationDate: self.mtimes[path]
            )
            result.append(FileItem(path: path, kind: .regularFile, attributes: attrs))
        }
        return result.sorted { $0.path.posixString < $1.path.posixString }
    }
}

// MARK: - RecordingSyncExecutor

/// Records copy/delete calls; actor for Swift 6 isolation.
actor RecordingSyncExecutor: SyncFileExecutor {
    private(set) var copies: [(source: FilePath, destination: FilePath)] = []
    private(set) var deletes: [FilePath] = []
    var error: (any Error)?

    func copy(
        from source: FilePath,
        on sourceProvider: any FileSystemProvider,
        to destination: FilePath,
        on destinationProvider: any FileSystemProvider
    ) async throws {
        if let error { throw error }
        self.copies.append((source: source, destination: destination))
    }

    func delete(at path: FilePath, on provider: any FileSystemProvider) async throws {
        if let error { throw error }
        self.deletes.append(path)
    }
}
