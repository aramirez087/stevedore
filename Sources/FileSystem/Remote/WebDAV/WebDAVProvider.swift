import Core
import Foundation

/// `FileSystemProvider` backed by a WebDAV transport.
///
/// Sends PROPFIND (depth 1) for enumeration, MKCOL for mkdir, MOVE for rename,
/// DELETE for delete, and conditional PUT (with If-Match ETag) for writes.
public actor WebDAVProvider: FileSystemProvider {
    public let scheme: ConnectionScheme = .webdav

    private let session: RemoteSession<any WebDAVTransport>
    private let descriptor: RemoteHostDescriptor
    private var etagCache: [String: String] = [:]

    private static let propfindBody = Data("""
    <?xml version="1.0" encoding="utf-8"?>
    <D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>
    """.utf8)

    public init(descriptor: RemoteHostDescriptor, session: RemoteSession<any WebDAVTransport>) {
        self.descriptor = descriptor
        self.session = session
    }

    // MARK: - FileSystemProvider

    public func attributes(at path: FilePath) async throws -> FileAttributes {
        let entries = try await propfind(at: path.posixString, depth: "0")
        guard let entry = entries.first else {
            throw StevedoreError.fileSystem(.notFound(path))
        }
        self.cacheETag(href: path.posixString, etag: entry.etag)
        return entry.fileAttributes
    }

    public nonisolated func enumerate(
        at path: FilePath,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.enumerate(path: path, options: options, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func enumerate(
        path: FilePath,
        options: EnumerationOptions,
        continuation: AsyncThrowingStream<FileItem, any Error>.Continuation
    ) async throws {
        let pathStr = path.posixString
        let entries = try await propfind(at: pathStr, depth: "1")
        for entry in entries {
            try Task.checkCancellation()
            let name = self.hrefLastComponent(entry.href)
            if name.isEmpty || entry.href.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ==
                pathStr.trimmingCharacters(in: CharacterSet(charactersIn: "/")) { continue }
            if !options.includesHiddenFiles, name.hasPrefix(".") { continue }
            self.cacheETag(href: entry.href, etag: entry.etag)
            continuation.yield(entry.fileItem(scheme: path.scheme))
        }
        continuation.finish()
    }

    public func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        switch operation.kind {
        case .mkdir: try await self.executeMkdir(operation)
        case .delete, .trash: try await self.executeDelete(operation)
        case .rename: try await self.executeRename(operation)
        case .copy: try await self.executeCopy(operation)
        default:
            OperationResult(descriptorID: operation.id, status: .skipped, bytesProcessed: 0, itemsProcessed: 0)
        }
    }

    private func executeMkdir(_ op: OperationDescriptor) async throws -> OperationResult {
        guard let dest = op.destination else {
            throw StevedoreError.invalidArgument("mkdir requires destination")
        }
        let resp = try await session.withTransport { t in
            try await t.request(method: "MKCOL", path: dest.posixString, headers: [:], body: nil)
        }
        guard resp.statusCode == 201 || resp.statusCode == 200 else {
            throw StevedoreError.fileSystem(.ioFailure(detail: "MKCOL failed: \(resp.statusCode)"))
        }
        return OperationResult(descriptorID: op.id, status: .completed, bytesProcessed: 0, itemsProcessed: 1)
    }

    private func executeDelete(_ op: OperationDescriptor) async throws -> OperationResult {
        guard let source = op.sources.first else {
            throw StevedoreError.invalidArgument("delete requires source")
        }
        let resp = try await session.withTransport { t in
            try await t.request(method: "DELETE", path: source.posixString, headers: [:], body: nil)
        }
        guard (200 ..< 300).contains(resp.statusCode) else {
            throw StevedoreError.fileSystem(.ioFailure(detail: "DELETE failed: \(resp.statusCode)"))
        }
        return OperationResult(descriptorID: op.id, status: .completed, bytesProcessed: 0, itemsProcessed: 1)
    }

    private func executeRename(_ op: OperationDescriptor) async throws -> OperationResult {
        guard let source = op.sources.first, let dest = op.destination else {
            throw StevedoreError.invalidArgument("rename requires source and destination")
        }
        let resp = try await session.withTransport { t in
            try await t.request(
                method: "MOVE",
                path: source.posixString,
                headers: ["Destination": dest.posixString, "Overwrite": "T"],
                body: nil
            )
        }
        guard (200 ..< 300).contains(resp.statusCode) else {
            throw StevedoreError.fileSystem(.ioFailure(detail: "MOVE failed: \(resp.statusCode)"))
        }
        return OperationResult(descriptorID: op.id, status: .completed, bytesProcessed: 0, itemsProcessed: 1)
    }

    private func executeCopy(_ op: OperationDescriptor) async throws -> OperationResult {
        guard let source = op.sources.first, let dest = op.destination else {
            throw StevedoreError.invalidArgument("copy requires source and destination")
        }
        let resp = try await session.withTransport { t in
            try await t.request(
                method: "COPY",
                path: source.posixString,
                headers: ["Destination": dest.posixString, "Overwrite": "T"],
                body: nil
            )
        }
        guard (200 ..< 300).contains(resp.statusCode) else {
            throw StevedoreError.fileSystem(.ioFailure(detail: "COPY failed: \(resp.statusCode)"))
        }
        return OperationResult(descriptorID: op.id, status: .completed, bytesProcessed: 0, itemsProcessed: 1)
    }

    public nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream { continuation in continuation.finish() }
    }

    // MARK: - Private helpers

    private func propfind(at path: String, depth: String) async throws -> [WebDAVEntry] {
        let responseData = try await session.withTransport { t in
            let resp = try await t.request(
                method: "PROPFIND",
                path: path,
                headers: ["Depth": depth, "Content-Type": "application/xml"],
                body: WebDAVProvider.propfindBody
            )
            guard resp.statusCode == 207, let body = resp.body else {
                throw StevedoreError.remote(.protocolMismatch(detail: "Expected 207, got \(resp.statusCode)"))
            }
            return body
        }
        return try PropFindParser.parse(data: responseData)
    }

    private func cacheETag(href: String, etag: String?) {
        guard let etag else { return }
        self.etagCache[href] = etag
    }

    private func hrefLastComponent(_ href: String) -> String {
        href.split(separator: "/").last.map(String.init) ?? ""
    }
}

// MARK: - WebDAVEntry helpers

extension WebDAVEntry {
    var fileAttributes: FileAttributes {
        FileAttributes(
            sizeInBytes: contentLength,
            modificationDate: lastModified,
            isHidden: (displayName ?? "").hasPrefix(".")
        )
    }

    func fileItem(scheme: ConnectionScheme) -> FileItem {
        FileItem(
            path: FilePath(scheme: scheme, posix: href),
            kind: isCollection ? .directory : .regularFile,
            attributes: self.fileAttributes
        )
    }
}
