import Core
import Foundation
import ZIPFoundation

/// Archive backend that reads and writes ZIP archives using ZIPFoundation.
///
/// All synchronous I/O is dispatched onto a detached task to keep the calling
/// context responsive. `Archive` (a class) is created, used, and released
/// within a single detached task — never captured across `await`.
public struct ZipBackend: ArchiveBackend {
    public let format: ArchiveFormat = .zip

    public init() {}

    func listEntries(at archive: URL) async throws -> [ArchiveEntry] {
        try await Task.detached(priority: .userInitiated) {
            try self.listEntriesSync(at: archive)
        }.value
    }

    func extractAll(
        from archive: URL,
        to destination: URL,
        progress: (any OperationProgressReporting)?
    ) async throws {
        let entries = try await self.listEntries(at: archive)
        let totalBytes = entries.compactMap(\.sizeInBytes).reduce(0, +)
        var bytesDone: Int64 = 0

        for entry in entries {
            try Task.checkCancellation()

            let destURL = destination.appendingPathComponent(entry.relativePath)
            if entry.kind == .directory {
                try FileManager.default.createDirectory(
                    at: destURL,
                    withIntermediateDirectories: true
                )
                continue
            }
            let parentDir = destURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

            try await self.extractEntry(at: entry.relativePath, from: archive, to: destURL)

            bytesDone += entry.sizeInBytes ?? 0
            if let reporter = progress {
                await reporter.report(Progress(
                    bytesDone: bytesDone,
                    bytesTotal: totalBytes,
                    phase: .transferring,
                    currentItemDisplayName: entry.pathComponents.last
                ))
            }
        }
    }

    /// Extract a single named entry from the archive to a destination file URL.
    public func extractEntry(at relativePath: String, from archive: URL, to file: URL) async throws {
        let entryPath = relativePath
        let fileURL = file
        try await Task.detached(priority: .userInitiated) {
            let zip = try Archive(url: archive, accessMode: .read)
            guard let entry = zip[entryPath] else {
                throw StevedoreError.fileSystem(.notFound(FilePath(scheme: .local, posix: entryPath)))
            }
            _ = try zip.extract(entry, to: fileURL, bufferSize: 65536, skipCRC32: false)
        }.value
    }

    /// Stream the raw bytes of a named entry.
    public func streamRead(entryPath: String, from archive: URL) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    let zip = try Archive(url: archive, accessMode: .read)
                    guard let entry = zip[entryPath] else {
                        throw StevedoreError.fileSystem(.notFound(FilePath(scheme: .local, posix: entryPath)))
                    }
                    _ = try zip.extract(entry, bufferSize: 65536) { chunk in
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private

    private func listEntriesSync(at archive: URL) throws -> [ArchiveEntry] {
        let zip = try Archive(url: archive, accessMode: .read)
        var entries: [ArchiveEntry] = []
        for entry in zip {
            // Strip trailing slash that ZIP directories often carry.
            let rawPath = entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
            guard !rawPath.isEmpty else { continue }

            let components = try validateAndSplitEntryPath(rawPath)

            let kind: FileKind = switch entry.type {
            case .file: .regularFile
            case .directory: .directory
            case .symlink: .symbolicLink
            }

            let attrs = entry.fileAttributes
            let mtime = attrs[.modificationDate] as? Date
            let permissions: PosixPermissions? = if let modeNum = attrs[.posixPermissions] as? NSNumber {
                PosixPermissions(rawMode: UInt16(truncatingIfNeeded: modeNum.uint64Value))
            } else {
                nil
            }

            let size: Int64? = entry.type == .file ? Int64(entry.uncompressedSize) : nil
            let symlinkTarget: String? = entry.type == .symlink ? entry.path : nil

            entries.append(ArchiveEntry(
                pathComponents: components,
                kind: kind,
                sizeInBytes: size,
                modificationDate: mtime,
                permissions: permissions,
                symbolicLinkTarget: symlinkTarget
            ))
        }
        return entries
    }
}
