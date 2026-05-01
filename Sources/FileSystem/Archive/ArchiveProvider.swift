import Core
import Foundation

/// A `FileSystemProvider` that mounts an archive file as a virtual read-only
/// filesystem. The archive root appears as a directory; entries inside are
/// exposed as `FileItem` values with `.local` scheme paths.
///
/// Write operations other than `.extract` throw `StevedoreError.unsupported`
/// in the MVP.
public actor ArchiveProvider: FileSystemProvider {
    public nonisolated let scheme: ConnectionScheme

    private let archiveURL: URL
    private let format: ArchiveFormat
    private let backend: any ArchiveBackend
    private var cachedEntries: [ArchiveEntry]?

    /// Open an archive file as a virtual filesystem.
    ///
    /// - Parameters:
    ///   - archiveURL: Path to the archive on the local filesystem.
    ///   - scheme: Scheme to report for all paths (defaults to `.local`).
    /// - Throws: `StevedoreError.fileSystem(.notFound)` or
    ///   `StevedoreError.archive(.unsupportedFormat)` on failure.
    public init(archiveURL: URL, scheme: ConnectionScheme = .local) async throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: archiveURL.path, isDirectory: &isDir),
              !isDir.boolValue
        else {
            throw StevedoreError.fileSystem(.notFound(FilePath(scheme: scheme, posix: archiveURL.path)))
        }
        guard let detectedFormat = await ArchiveDetector.detect(at: archiveURL) else {
            throw StevedoreError.archive(.unsupportedFormat)
        }
        self.archiveURL = archiveURL
        self.scheme = scheme
        self.format = detectedFormat
        switch detectedFormat {
        case .zip:
            self.backend = ZipBackend()
        case .tar, .tarGzip, .tarBzip2:
            self.backend = try TarBackend(format: detectedFormat)
        }
    }

    // MARK: - FileSystemProvider

    public func attributes(at path: FilePath) async throws -> FileAttributes {
        if path.isRoot || path.components == self.archiveURL.pathComponents.map(\.self) {
            // Synthesise root attributes from the archive file on disk.
            let fsAttrs = try FileManager.default.attributesOfItem(atPath: self.archiveURL.path)
            return FileAttributes(
                sizeInBytes: (fsAttrs[.size] as? NSNumber)?.int64Value,
                modificationDate: fsAttrs[.modificationDate] as? Date,
                isHidden: false
            )
        }
        let entries = try await self.loadEntries()
        // Match entry whose components correspond to the trailing portion of `path`.
        let archiveComponents = FilePath(scheme: self.scheme, posix: self.archiveURL.path).components
        let entryComponents: [String] = if path.components.count > archiveComponents.count {
            Array(path.components.dropFirst(archiveComponents.count))
        } else {
            path.components
        }
        guard let entry = entries.first(where: { $0.pathComponents == entryComponents }) else {
            throw StevedoreError.fileSystem(.notFound(path))
        }
        return FileAttributes(
            sizeInBytes: entry.sizeInBytes,
            modificationDate: entry.modificationDate,
            permissions: entry.permissions,
            isHidden: entry.pathComponents.last?.hasPrefix(".") ?? false,
            isSymbolicLink: entry.kind == .symbolicLink,
            symbolicLinkTarget: entry.symbolicLinkTarget
        )
    }

    public nonisolated func enumerate(
        at path: FilePath,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let items = try await self.snapshot(at: path, options: options)
                    for item in items {
                        continuation.yield(item)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        guard operation.kind == .extract else {
            throw StevedoreError.unsupported("ArchiveProvider is read-only in MVP")
        }
        guard let destination = operation.destination else {
            throw StevedoreError.invalidArgument("extract operation requires a destination path")
        }
        guard destination.scheme == .local else {
            throw StevedoreError.invalidArgument("extract destination must be a local path")
        }
        let destURL = URL(fileURLWithPath: destination.posixString)
        let extractor = ArchiveExtractor(progress: progress, conflictPolicy: operation.conflictPolicy)
        let result = try await extractor.extract(archive: self.archiveURL, to: destURL)
        return OperationResult(
            descriptorID: operation.id,
            status: .completed,
            bytesProcessed: result.bytesProcessed,
            itemsProcessed: result.entriesExtracted
        )
    }

    public nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        // Archives don't change while mounted in the MVP.
        AsyncStream { continuation in continuation.finish() }
    }

    // MARK: - Private

    private func loadEntries() async throws -> [ArchiveEntry] {
        if let cached = self.cachedEntries { return cached }
        let entries = try await self.backend.listEntries(at: self.archiveURL)
        self.cachedEntries = entries
        return entries
    }

    private func snapshot(at path: FilePath, options: EnumerationOptions) async throws -> [FileItem] {
        let entries = try await self.loadEntries()
        let archivePath = FilePath(scheme: self.scheme, posix: self.archiveURL.path)
        let mountComponents = archivePath.components

        // Determine the path components relative to the archive mount.
        let relativeComponents: [String] = if path.isRoot || path.components == mountComponents {
            []
        } else if path.components.count > mountComponents.count {
            Array(path.components.dropFirst(mountComponents.count))
        } else {
            path.components
        }

        let targetDepth = relativeComponents.count + 1

        return entries
            .filter { entry in
                // Must start with the relative prefix.
                guard entry.pathComponents.count >= relativeComponents.count else { return false }
                let prefix = Array(entry.pathComponents.prefix(relativeComponents.count))
                guard prefix == relativeComponents else { return false }
                // Depth filter.
                if options.isRecursive {
                    return entry.pathComponents.count > relativeComponents.count
                } else {
                    return entry.pathComponents.count == targetDepth
                }
            }
            .filter { entry in
                options.includesHiddenFiles || !(entry.pathComponents.last?.hasPrefix(".") ?? false)
            }
            .map { $0.asFileItem(mountComponents: mountComponents, scheme: self.scheme) }
            .sorted { $0.path.posixString < $1.path.posixString }
    }
}
