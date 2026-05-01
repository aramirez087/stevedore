import Core
import Foundation

/// `FileSystemProvider` backed by an S3 transport.
///
/// Path mapping:
/// - Root path → list all buckets.
/// - `FilePath(components: [bucket])` → list objects at root of bucket.
/// - `FilePath(components: [bucket, "prefix", "name"])` → object with key "prefix/name".
///
/// S3 directories are virtual: `listObjectsV2` with `delimiter: "/"` returns
/// common prefixes as virtual directory entries.
public actor S3Provider: FileSystemProvider {
    public let scheme: ConnectionScheme = .s3

    private let session: RemoteSession<any S3Transport>
    private let descriptor: RemoteHostDescriptor

    private static let multipartThreshold = 8 * 1024 * 1024 // 8 MB

    public init(descriptor: RemoteHostDescriptor, session: RemoteSession<any S3Transport>) {
        self.descriptor = descriptor
        self.session = session
    }

    // MARK: - FileSystemProvider

    public func attributes(at path: FilePath) async throws -> FileAttributes {
        guard !path.isRoot else {
            return FileAttributes(isHidden: false)
        }
        let (bucket, key) = self.s3Coordinates(path)
        if key.isEmpty {
            // Bucket-level stat — just confirm it exists via a list
            _ = try await self.session.withTransport { t in
                try await t.listObjects(bucket: bucket, prefix: nil, delimiter: "/", continuationToken: nil)
            }
            return FileAttributes()
        }
        let obj = try await session.withTransport { t in
            try await t.headObject(bucket: bucket, key: key)
        }
        return obj.fileAttributes
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
        if path.isRoot {
            let buckets = try await session.withTransport { t in
                try await t.listBuckets()
            }
            for bucket in buckets {
                try Task.checkCancellation()
                if !options.includesHiddenFiles, bucket.hasPrefix(".") { continue }
                continuation.yield(FileItem(
                    path: FilePath(scheme: path.scheme, components: [bucket]),
                    kind: .directory
                ))
            }
            continuation.finish()
            return
        }

        let (bucket, prefix) = self.s3Coordinates(path)
        let listPrefix = prefix.isEmpty ? nil : (prefix.hasSuffix("/") ? prefix : prefix + "/")
        var continuationToken: String?
        repeat {
            try Task.checkCancellation()
            let token = continuationToken
            let result = try await session.withTransport { t in
                try await t.listObjects(
                    bucket: bucket,
                    prefix: listPrefix,
                    delimiter: "/",
                    continuationToken: token
                )
            }
            for prefixEntry in result.prefixes {
                try Task.checkCancellation()
                let name = self.virtualDirectoryName(prefixEntry, strippingPrefix: listPrefix)
                if name.isEmpty { continue }
                if !options.includesHiddenFiles, name.hasPrefix(".") { continue }
                let entryPath = prefixEntry.hasSuffix("/")
                    ? FilePath(scheme: path.scheme, posix: "/\(bucket)/\(prefixEntry.dropLast())")
                    : FilePath(scheme: path.scheme, posix: "/\(bucket)/\(prefixEntry)")
                continuation.yield(FileItem(path: entryPath, kind: .directory))
            }
            for obj in result.objects {
                try Task.checkCancellation()
                let name = self.objectName(obj.key, strippingPrefix: listPrefix)
                if name.isEmpty { continue }
                if !options.includesHiddenFiles, name.hasPrefix(".") { continue }
                continuation.yield(obj.fileItem(bucket: bucket, scheme: path.scheme))
            }
            continuationToken = result.nextToken
        } while continuationToken != nil
        continuation.finish()
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
            let (bucket, key) = self.s3Coordinates(dest)
            let dirKey = key.hasSuffix("/") ? key : key + "/"
            try await self.session.withTransport { t in
                try await t.putObject(bucket: bucket, key: dirKey, data: Data(), contentType: nil)
            }
            return OperationResult(descriptorID: operation.id, status: .completed, bytesProcessed: 0, itemsProcessed: 1)

        case .delete, .trash:
            guard let source = operation.sources.first else {
                throw StevedoreError.invalidArgument("delete requires source")
            }
            let (bucket, key) = self.s3Coordinates(source)
            try await self.session.withTransport { t in
                try await t.deleteObject(bucket: bucket, key: key)
            }
            return OperationResult(descriptorID: operation.id, status: .completed, bytesProcessed: 0, itemsProcessed: 1)

        case .rename:
            guard let source = operation.sources.first, let dest = operation.destination else {
                throw StevedoreError.invalidArgument("rename requires source and destination")
            }
            let (srcBucket, srcKey) = self.s3Coordinates(source)
            let (dstBucket, dstKey) = self.s3Coordinates(dest)
            // S3 has no native rename: copy then delete.
            let data = try await collectObject(bucket: srcBucket, key: srcKey)
            try await session.withTransport { t in
                try await t.putObject(bucket: dstBucket, key: dstKey, data: data, contentType: nil)
                try await t.deleteObject(bucket: srcBucket, key: srcKey)
            }
            return OperationResult(
                descriptorID: operation.id,
                status: .completed,
                bytesProcessed: Int64(data.count),
                itemsProcessed: 1
            )

        default:
            return OperationResult(descriptorID: operation.id, status: .skipped, bytesProcessed: 0, itemsProcessed: 0)
        }
    }

    public nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream { continuation in continuation.finish() }
    }

    // MARK: - Helpers

    /// Returns `(bucket, key)` for a given path.
    /// Root → `("", "")`, bucket-only → `("mybucket", "")`,
    /// file → `("mybucket", "prefix/name")`.
    private func s3Coordinates(_ path: FilePath) -> (String, String) {
        guard !path.components.isEmpty else { return ("", "") }
        let bucket = path.components[0]
        let key = path.components.dropFirst().joined(separator: "/")
        return (bucket, key)
    }

    private func virtualDirectoryName(_ prefix: String, strippingPrefix listPrefix: String?) -> String {
        var name = prefix
        if let lp = listPrefix, name.hasPrefix(lp) {
            name = String(name.dropFirst(lp.count))
        }
        return name.hasSuffix("/") ? String(name.dropLast()) : name
    }

    private func objectName(_ key: String, strippingPrefix listPrefix: String?) -> String {
        guard let lp = listPrefix, key.hasPrefix(lp) else { return key }
        return String(key.dropFirst(lp.count))
    }

    private func collectObject(bucket: String, key: String) async throws -> Data {
        let stream = try await session.withTransport { t in
            t.getObject(bucket: bucket, key: key)
        }
        var data = Data()
        for try await chunk in stream {
            data.append(chunk)
        }
        return data
    }
}

// MARK: - S3Object helpers

extension S3Object {
    var fileAttributes: FileAttributes {
        FileAttributes(
            sizeInBytes: sizeInBytes,
            modificationDate: lastModified,
            isHidden: false
        )
    }

    func fileItem(bucket: String, scheme: ConnectionScheme) -> FileItem {
        let keyPath = key.hasSuffix("/") ? String(key.dropLast()) : key
        let fullPath = keyPath.isEmpty ? bucket : "\(bucket)/\(keyPath)"
        return FileItem(
            path: FilePath(scheme: scheme, posix: "/\(fullPath)"),
            kind: isDirectory ? .directory : .regularFile,
            attributes: self.fileAttributes
        )
    }
}
