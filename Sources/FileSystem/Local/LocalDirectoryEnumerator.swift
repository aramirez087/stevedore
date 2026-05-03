import Core
import Foundation

/// Bridges `FileManager.enumerator(at:includingPropertiesForKeys:options:)` into
/// `AsyncThrowingStream<FileItem, any Error>`, honoring `EnumerationOptions`.
enum LocalDirectoryEnumerator {
    /// Build an `AsyncThrowingStream` that lazily enumerates `directoryURL`.
    static func stream(
        at directoryURL: URL,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    try Self.enumerate(
                        at: directoryURL,
                        options: options,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // Keys sufficient for directory listing. Omits .fileSecurityKey and
    // .isPackageKey to avoid per-entry ACL/UTI syscalls during enumeration.
    // attributes(at:) uses the full URLResourceMapperKeys for single-item queries.
    private static let enumerationKeys: Set<URLResourceKey> = {
        var keys = URLResourceMapperKeys
        keys.remove(.fileSecurityKey)
        keys.remove(.isPackageKey)
        return keys
    }()

    // MARK: - Private

    private static func enumerate(
        at directoryURL: URL,
        options: EnumerationOptions,
        continuation: AsyncThrowingStream<FileItem, any Error>.Continuation
    ) throws {
        let fm = FileManager()

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directoryURL.path, isDirectory: &isDir) else {
            throw StevedoreError.fileSystem(.notFound(FilePath(scheme: .local, posix: directoryURL.path)))
        }
        guard isDir.boolValue else {
            throw StevedoreError.fileSystem(.notADirectory(FilePath(scheme: .local, posix: directoryURL.path)))
        }

        // Explicitly check readability so we surface permissionDenied rather
        // than silently producing an empty enumeration.
        guard fm.isReadableFile(atPath: directoryURL.path) else {
            throw StevedoreError.fileSystem(
                .permissionDenied(FilePath(scheme: .local, posix: directoryURL.path))
            )
        }

        var fmOptions: FileManager.DirectoryEnumerationOptions = []
        if !options.includesHiddenFiles { fmOptions.insert(.skipsHiddenFiles) }
        if !options.isRecursive { fmOptions.insert(.skipsSubdirectoryDescendants) }

        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: Array(Self.enumerationKeys),
            options: fmOptions
        ) else {
            throw StevedoreError.fileSystem(
                .ioFailure(detail: "Could not create enumerator for \(directoryURL.path)")
            )
        }

        for case let url as URL in enumerator {
            if Task.isCancelled { break }

            do {
                let values = try url.resourceValues(forKeys: Self.enumerationKeys)
                if !options.followsSymbolicLinks && values.isSymbolicLink == true {
                    enumerator.skipDescendants()
                }
                let item = URLResourceMapper.fileItem(url: url, values: values)
                continuation.yield(item)
            } catch let nsError as NSError where nsError.code == NSFileReadNoPermissionError {
                let path = FilePath(scheme: .local, posix: url.path)
                throw StevedoreError.fileSystem(.permissionDenied(path))
            } catch {
                throw StevedoreError.fileSystem(.ioFailure(detail: error.localizedDescription))
            }
        }
    }
}
