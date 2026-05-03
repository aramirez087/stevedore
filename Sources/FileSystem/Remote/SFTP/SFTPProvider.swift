import Core
import Foundation

/// `FileSystemProvider` backed by an SFTP transport.
///
/// All operations delegate to the injected `SFTPTransport`. The real transport
/// (`CitadelSFTPTransport`) is wired at startup; fakes are injected in tests.
public actor SFTPProvider: FileSystemProvider {
    public let scheme: ConnectionScheme = .sftp

    private let session: RemoteSession<any SFTPTransport>
    private let descriptor: RemoteHostDescriptor

    public init(descriptor: RemoteHostDescriptor, session: RemoteSession<any SFTPTransport>) {
        self.descriptor = descriptor
        self.session = session
    }

    // MARK: - FileSystemProvider

    public func attributes(at path: FilePath) async throws -> FileAttributes {
        let entry = try await session.withTransport { transport in
            try await transport.stat(at: path.posixString)
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
                    let entries = try await session.withTransport { transport in
                        try await transport.listDirectory(at: path.posixString)
                    }
                    for entry in entries {
                        try Task.checkCancellation()
                        if !options.includesHiddenFiles, entry.name.hasPrefix(".") { continue }
                        continuation.yield(entry.fileItem(scheme: path.scheme))
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
                throw StevedoreError.invalidArgument("mkdir requires a destination path")
            }
            try await self.session.withTransport { transport in
                try await transport.createDirectory(at: dest.posixString)
            }
            return OperationResult(
                descriptorID: operation.id,
                status: .completed,
                bytesProcessed: 0,
                itemsProcessed: 1
            )

        case .delete, .trash:
            guard let source = operation.sources.first else {
                throw StevedoreError.invalidArgument("delete requires at least one source")
            }
            try await self.session.withTransport { transport in
                try await transport.remove(at: source.posixString)
            }
            return OperationResult(
                descriptorID: operation.id,
                status: .completed,
                bytesProcessed: 0,
                itemsProcessed: operation.sources.count
            )

        case .rename:
            guard let source = operation.sources.first, let dest = operation.destination else {
                throw StevedoreError.invalidArgument("rename requires source and destination")
            }
            try await self.session.withTransport { transport in
                try await transport.rename(from: source.posixString, to: dest.posixString)
            }
            return OperationResult(
                descriptorID: operation.id,
                status: .completed,
                bytesProcessed: 0,
                itemsProcessed: 1
            )

        case .copy:
            guard let source = operation.sources.first, let dest = operation.destination else {
                throw StevedoreError.invalidArgument("copy requires source and destination")
            }
            // RETR + STOR: download source, upload to destination
            let readStream = try await session.withTransport { transport in
                transport.readFile(at: source.posixString, fromOffset: 0)
            }
            try await self.session.withTransport { transport in
                try await transport.writeFile(at: dest.posixString, data: readStream)
            }
            return OperationResult(
                descriptorID: operation.id,
                status: .completed,
                bytesProcessed: 0,
                itemsProcessed: 1
            )

        default:
            return OperationResult(
                descriptorID: operation.id,
                status: .skipped,
                bytesProcessed: 0,
                itemsProcessed: 0
            )
        }
    }

    public nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream { continuation in continuation.finish() }
    }

    // MARK: - SFTP-specific

    /// Set POSIX permissions on a remote path. Not surfaced through `OperationKind`.
    public func chmod(at path: FilePath, permissions: UInt32) async throws {
        try await self.session.withTransport { transport in
            try await transport.chmod(at: path.posixString, permissions: permissions)
        }
    }
}

// MARK: - SFTPEntry helpers

extension SFTPEntry {
    var fileAttributes: FileAttributes {
        let perms = permissions.map { PosixPermissions(rawMode: UInt16($0 & 0o777)) }
        return FileAttributes(
            sizeInBytes: sizeInBytes,
            modificationDate: modificationDate,
            permissions: perms,
            isHidden: name.hasPrefix("."),
            isSymbolicLink: isSymlink,
            symbolicLinkTarget: symbolicLinkTarget
        )
    }

    func fileItem(scheme: ConnectionScheme) -> FileItem {
        let kind: FileKind = if isSymlink {
            .symbolicLink
        } else if isDirectory {
            .directory
        } else {
            .regularFile
        }
        return FileItem(
            path: FilePath(scheme: scheme, posix: posixPath),
            kind: kind,
            attributes: self.fileAttributes
        )
    }
}
