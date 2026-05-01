import Core
import FeaturesOperations
import Foundation
import XCTest

// MARK: - TestDataProvider

/// In-memory `FileSystemProvider` + `DataReadableProvider` + `DataWritableProvider`
/// for use in Operations unit tests. Backed by an actor with `[FilePath: Data]` storage.
public actor TestDataProvider: DataReadableProvider, DataWritableProvider {
    public let scheme: ConnectionScheme

    private var files: [FilePath: Data] = [:]
    private var directories: Set<FilePath> = []
    public private(set) var deletePartialCalls: [FilePath] = []
    /// Simulated chunk size for streaming; nil uses the caller's hint.
    public var simulatedChunkSize: Int?

    public init(scheme: ConnectionScheme = .local) {
        self.scheme = scheme
    }

    // MARK: Seeding

    public func seed(file path: FilePath, data: Data) {
        self.files[path] = data
    }

    public func seed(directory path: FilePath) {
        self.directories.insert(path)
    }

    // MARK: Inspection

    public func data(at path: FilePath) -> Data? {
        self.files[path]
    }

    public var allPaths: Set<FilePath> {
        Set(self.files.keys).union(self.directories)
    }

    // MARK: FileSystemProvider

    public func attributes(at path: FilePath) async throws -> FileAttributes {
        if let data = self.files[path] {
            return FileAttributes(sizeInBytes: Int64(data.count))
        }
        if self.directories.contains(path) {
            return FileAttributes()
        }
        throw StevedoreError.fileSystem(.notFound(path))
    }

    public nonisolated func enumerate(
        at path: FilePath,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                let items = await self.fileItems(under: path, recursive: options.isRecursive)
                for item in items {
                    continuation.yield(item)
                }
                continuation.finish()
            }
        }
    }

    public func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        switch operation.kind {
        case .mkdir:
            if let dest = operation.destination {
                self.directories.insert(dest)
            }
            return OperationResult(
                descriptorID: operation.id,
                status: .completed,
                bytesProcessed: 0,
                itemsProcessed: 1
            )
        case .delete:
            for src in operation.sources {
                self.files.removeValue(forKey: src)
                self.directories.remove(src)
            }
            return OperationResult(
                descriptorID: operation.id,
                status: .completed,
                bytesProcessed: 0,
                itemsProcessed: operation.sources.count
            )
        case .rename:
            if let src = operation.sources.first, let dest = operation.destination,
               let data = self.files[src] {
                self.files.removeValue(forKey: src)
                self.files[dest] = data
            }
            return OperationResult(
                descriptorID: operation.id,
                status: .completed,
                bytesProcessed: 0,
                itemsProcessed: 1
            )
        default:
            throw StevedoreError.unsupported("TestDataProvider: \(operation.kind) not implemented")
        }
    }

    public nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream { continuation in continuation.finish() }
    }

    // MARK: DataReadableProvider

    public nonisolated func read(
        at path: FilePath,
        chunkSize: Int
    ) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                let data = await self.files[path]
                guard let data else {
                    continuation.finish(
                        throwing: StevedoreError.fileSystem(.notFound(path))
                    )
                    return
                }
                let actualChunk = await self.simulatedChunkSize ?? chunkSize
                var offset = 0
                while offset < data.count {
                    let end = min(offset + actualChunk, data.count)
                    continuation.yield(data[offset ..< end])
                    offset = end
                }
                continuation.finish()
            }
        }
    }

    // MARK: DataWritableProvider

    public func writeChunk(
        _ data: Data,
        to destination: FilePath,
        isFirst: Bool,
        isLast: Bool
    ) async throws {
        if isFirst {
            self.files[destination] = data
        } else {
            self.files[destination, default: Data()].append(data)
        }
    }

    public func deletePartial(at path: FilePath) async throws {
        self.deletePartialCalls.append(path)
        self.files.removeValue(forKey: path)
    }

    // MARK: Private

    private func fileItems(under root: FilePath, recursive: Bool) -> [FileItem] {
        var result: [FileItem] = []
        for path in self.files.keys {
            guard self.isChild(path: path, of: root, recursive: recursive) else { continue }
            let attrs = FileAttributes(sizeInBytes: Int64(self.files[path]?.count ?? 0))
            result.append(FileItem(path: path, kind: .regularFile, attributes: attrs))
        }
        for path in self.directories {
            guard self.isChild(path: path, of: root, recursive: recursive) else { continue }
            result.append(FileItem(path: path, kind: .directory, attributes: .empty))
        }
        return result
    }

    private func isChild(path: FilePath, of root: FilePath, recursive: Bool) -> Bool {
        guard path.scheme == root.scheme,
              path.components.count > root.components.count else { return false }
        let prefix = Array(path.components.prefix(root.components.count))
        guard prefix == root.components else { return false }
        if !recursive {
            return path.components.count == root.components.count + 1
        }
        return true
    }
}

// MARK: - RecordingProgressReporter

public actor RecordingProgressReporter: OperationProgressReporting {
    public private(set) var reports: [Core.Progress] = []

    public init() {}

    public func report(_ progress: Core.Progress) async {
        self.reports.append(progress)
    }

    public func reset() {
        self.reports = []
    }
}

// MARK: - Helpers

extension FilePath {
    static func local(_ posix: String) -> FilePath {
        FilePath(scheme: .local, posix: posix)
    }

    static func remote(_ posix: String) -> FilePath {
        FilePath(scheme: .sftp, posix: posix)
    }
}
