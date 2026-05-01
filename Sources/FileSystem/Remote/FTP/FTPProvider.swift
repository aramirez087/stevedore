import Core
import Foundation

/// `FileSystemProvider` backed by an FTP transport.
///
/// MLSD is preferred over LIST; falls back to LIST automatically.
/// UTF-8 decoding is attempted first; Latin-1 is the fallback when replacement
/// characters appear in the result.
public actor FTPProvider: FileSystemProvider {
    public let scheme: ConnectionScheme = .ftp

    private let session: RemoteSession<any FTPTransport>
    private let descriptor: RemoteHostDescriptor

    public init(descriptor: RemoteHostDescriptor, session: RemoteSession<any FTPTransport>) {
        self.descriptor = descriptor
        self.session = session
    }

    // MARK: - FileSystemProvider

    public func attributes(at path: FilePath) async throws -> FileAttributes {
        let entries = try await listEntries(at: path.parent ?? FilePath.root(path.scheme))
        let name = path.lastComponent ?? ""
        guard let entry = entries.first(where: { $0.name == name }) else {
            throw StevedoreError.fileSystem(.notFound(path))
        }
        return entry.fileAttributes
    }

    public nonisolated func enumerate(
        at path: FilePath,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let entries = try await listEntries(at: path)
                    for entry in entries {
                        try Task.checkCancellation()
                        if !options.includesHiddenFiles, entry.name.hasPrefix(".") { continue }
                        let entryPath = path.appending(entry.name)
                        continuation.yield(entry.fileItem(path: entryPath))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        switch operation.kind {
        case .mkdir:
            guard let dest = operation.destination else {
                throw StevedoreError.invalidArgument("mkdir requires destination")
            }
            try await self.session.withTransport { t in
                try await t.makeDirectory(at: dest.posixString)
            }
            return OperationResult(descriptorID: operation.id, status: .completed, bytesProcessed: 0, itemsProcessed: 1)

        case .delete, .trash:
            guard let source = operation.sources.first else {
                throw StevedoreError.invalidArgument("delete requires source")
            }
            try await self.session.withTransport { t in
                try await t.delete(at: source.posixString)
            }
            return OperationResult(descriptorID: operation.id, status: .completed, bytesProcessed: 0, itemsProcessed: 1)

        case .rename:
            guard let source = operation.sources.first, let dest = operation.destination else {
                throw StevedoreError.invalidArgument("rename requires source and destination")
            }
            try await self.session.withTransport { t in
                try await t.rename(from: source.posixString, to: dest.posixString)
            }
            return OperationResult(descriptorID: operation.id, status: .completed, bytesProcessed: 0, itemsProcessed: 1)

        default:
            return OperationResult(descriptorID: operation.id, status: .skipped, bytesProcessed: 0, itemsProcessed: 0)
        }
    }

    public nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream { continuation in continuation.finish() }
    }

    // MARK: - Private helpers

    private func listEntries(at path: FilePath) async throws -> [FTPEntry] {
        try await self.session.withTransport { transport in
            // Prefer MLSD; fall back to LIST on error.
            let rawData: Data
            var useMLSD = true
            do {
                rawData = try await transport.mlsd(at: path.posixString)
            } catch {
                useMLSD = false
                rawData = try await transport.list(at: path.posixString)
            }
            return Self.decode(rawData: rawData, useMLSD: useMLSD)
        }
    }

    private static func decode(rawData: Data, useMLSD: Bool) -> [FTPEntry] {
        func parse(_ str: String) -> [FTPEntry] {
            useMLSD ? FTPListParser.parseMLSDResponse(str) : FTPListParser.parseListResponse(str)
        }

        if let utf8 = String(data: rawData, encoding: .utf8), !utf8.contains("\u{FFFD}") {
            return parse(utf8)
        }
        if let latin1 = String(data: rawData, encoding: .isoLatin1) {
            return parse(latin1)
        }
        return []
    }
}

// MARK: - FTPEntry helpers

extension FTPEntry {
    var fileAttributes: FileAttributes {
        FileAttributes(
            sizeInBytes: sizeInBytes,
            modificationDate: modificationDate,
            isHidden: name.hasPrefix(".")
        )
    }

    func fileItem(path: FilePath) -> FileItem {
        FileItem(
            path: path,
            kind: isDirectory ? .directory : .regularFile,
            attributes: self.fileAttributes
        )
    }
}
