import Foundation

/// In-memory `FileSystemProvider` used by tests across every module.
///
/// State is held inside an actor so concurrent producers cannot tear it. The
/// provider exposes `seed(_:)` to plant a tree before any operation runs.
public actor InMemoryFileSystemProvider: FileSystemProvider {
    public nonisolated let scheme: ConnectionScheme

    private var nodes: [FilePath: FileItem]
    private var watchers: [FilePath: [UUID: AsyncStream<FilePathChange>.Continuation]] = [:]

    public init(scheme: ConnectionScheme = .local, items: [FileItem] = []) {
        self.scheme = scheme
        var seeded: [FilePath: FileItem] = [:]
        for item in items {
            seeded[item.path] = item
        }
        self.nodes = seeded
    }

    /// Replace the entire in-memory tree with `items`.
    public func seed(_ items: [FileItem]) {
        var fresh: [FilePath: FileItem] = [:]
        for item in items {
            fresh[item.path] = item
        }
        self.nodes = fresh
    }

    /// Insert or replace a single item.
    public func upsert(_ item: FileItem) {
        self.nodes[item.path] = item
        self.broadcast(.init(path: item.path, kind: .modified))
    }

    /// Remove an item if present.
    public func remove(at path: FilePath) {
        if self.nodes.removeValue(forKey: path) != nil {
            self.broadcast(.init(path: path, kind: .deleted))
        }
    }

    public func attributes(at path: FilePath) async throws -> FileAttributes {
        guard let item = nodes[path] else {
            throw StevedoreError.fileSystem(.notFound(path))
        }
        return item.attributes
    }

    public nonisolated func enumerate(
        at path: FilePath,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream<FileItem, any Error> { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                let items = await self.snapshotChildren(of: path, options: options)
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

    /// Internal lookup used by the enumeration stream.
    private func snapshotChildren(of path: FilePath, options: EnumerationOptions) -> [FileItem] {
        let prefix = path.components
        let depth = prefix.count
        var matches: [FileItem] = []
        for item in self.nodes.values {
            guard item.path.scheme == path.scheme else { continue }
            let candidate = item.path.components
            guard candidate.count > depth else { continue }
            guard Array(candidate.prefix(depth)) == prefix else { continue }
            if !options.isRecursive, candidate.count != depth + 1 { continue }
            if !options.includesHiddenFiles, item.attributes.isHidden { continue }
            matches.append(item)
        }
        matches.sort { $0.path.posixString < $1.path.posixString }
        return matches
    }

    public func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        await progress?.report(.init(bytesDone: 0, bytesTotal: 0, phase: .preparing))
        switch operation.kind {
        case .mkdir:
            for source in operation.sources {
                let item = FileItem(path: source, kind: .directory)
                self.nodes[source] = item
                self.broadcast(.init(path: source, kind: .created))
            }
        case .delete, .trash:
            for source in operation.sources where self.nodes[source] != nil {
                self.nodes.removeValue(forKey: source)
                self.broadcast(.init(path: source, kind: .deleted))
            }
        case .rename:
            guard let destination = operation.destination,
                  let source = operation.sources.first,
                  let item = nodes.removeValue(forKey: source)
            else {
                throw StevedoreError.invalidArgument("rename requires a single source and a destination")
            }
            self.nodes[destination] = FileItem(path: destination, kind: item.kind, attributes: item.attributes)
            self.broadcast(.init(path: source, kind: .renamed))
            self.broadcast(.init(path: destination, kind: .created))
        case .copy, .move, .symlink, .archive, .extract:
            // Stubbed for the in-memory fake — downstream tests that need these
            // can subclass or extend `seed`. The descriptor is acknowledged but
            // no tree mutation occurs here.
            break
        }
        await progress?.report(.init(bytesDone: 0, bytesTotal: 0, phase: .completed))
        return OperationResult(
            descriptorID: operation.id,
            status: .completed,
            bytesProcessed: 0,
            itemsProcessed: operation.sources.count
        )
    }

    public nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream<FilePathChange> { continuation in
            let token = UUID()
            Task { await self.registerWatcher(at: path, token: token, continuation: continuation) }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeWatcher(at: path, token: token) }
            }
        }
    }

    private func registerWatcher(
        at path: FilePath,
        token: UUID,
        continuation: AsyncStream<FilePathChange>.Continuation
    ) {
        var bucket = self.watchers[path] ?? [:]
        bucket[token] = continuation
        self.watchers[path] = bucket
    }

    private func removeWatcher(at path: FilePath, token: UUID) {
        guard var bucket = watchers[path] else { return }
        if let continuation = bucket.removeValue(forKey: token) {
            continuation.finish()
        }
        if bucket.isEmpty {
            self.watchers.removeValue(forKey: path)
        } else {
            self.watchers[path] = bucket
        }
    }

    private func broadcast(_ change: FilePathChange) {
        guard let parent = change.path.parent else { return }
        let bucket = self.watchers[parent] ?? [:]
        for continuation in bucket.values {
            continuation.yield(change)
        }
    }
}
