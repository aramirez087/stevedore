import Core
@testable import FileSystemRemote
import Foundation
import os

/// In-memory S3 transport for testing.
public final class FakeS3Transport: S3Transport, @unchecked Sendable {
    private struct State {
        var buckets: [String: [String: Data]] = [:] // bucket → (key → data)
    }

    private let lock: OSAllocatedUnfairLock<State>
    public var listError: (any Error)?

    public init(buckets: [String: [String: Data]] = [:]) {
        self.lock = OSAllocatedUnfairLock(initialState: State(buckets: buckets))
    }

    public func listObjects(
        bucket: String,
        prefix: String?,
        delimiter: String?,
        continuationToken: String?
    ) async throws -> S3ListPage {
        if let err = listError { throw err }
        return self.lock.withLock { state in
            guard let store = state.buckets[bucket]
            else { return S3ListPage(objects: [], prefixes: [], nextToken: nil) }

            var objects: [S3Object] = []
            var prefixes: Set<String> = []

            for (key, data) in store {
                if let p = prefix, !key.hasPrefix(p) { continue }
                let stripped = prefix.map { String(key.dropFirst($0.count)) } ?? key

                if let delim = delimiter, let delimRange = stripped.range(of: delim) {
                    let dirComponent = String(stripped[..<delimRange.upperBound])
                    prefixes.insert((prefix ?? "") + dirComponent)
                } else {
                    objects.append(S3Object(
                        key: key,
                        bucket: bucket,
                        sizeInBytes: Int64(data.count),
                        isDirectory: key.hasSuffix("/")
                    ))
                }
            }
            return S3ListPage(objects: objects, prefixes: Array(prefixes).sorted(), nextToken: nil)
        }
    }

    public func headObject(bucket: String, key: String) async throws -> S3Object {
        try self.lock.withLock { state in
            guard let data = state.buckets[bucket]?[key] else {
                throw StevedoreError.fileSystem(.notFound(FilePath(scheme: .s3, posix: "/\(bucket)/\(key)")))
            }
            return S3Object(key: key, bucket: bucket, sizeInBytes: Int64(data.count))
        }
    }

    public func getObject(bucket: String, key: String) -> AsyncThrowingStream<Data, any Error> {
        let data = self.lock.withLock { $0.buckets[bucket]?[key] }
        return AsyncThrowingStream { continuation in
            guard let d = data else {
                continuation.finish(
                    throwing: StevedoreError.fileSystem(.notFound(FilePath(scheme: .s3, posix: "/\(bucket)/\(key)")))
                )
                return
            }
            continuation.yield(d)
            continuation.finish()
        }
    }

    public func putObject(bucket: String, key: String, data: Data, contentType: String?) async throws {
        self.lock.withLock { state in
            state.buckets[bucket, default: [:]][key] = data
        }
    }

    public func putObjectMultipart(
        bucket: String,
        key: String,
        data: AsyncThrowingStream<Data, any Error>,
        contentType: String?
    ) async throws {
        var collected = Data()
        for try await chunk in data {
            collected.append(chunk)
        }
        try await self.putObject(bucket: bucket, key: key, data: collected, contentType: contentType)
    }

    public func deleteObject(bucket: String, key: String) async throws {
        self.lock.withLock { $0.buckets[bucket]?[key] = nil }
    }

    public func listBuckets() async throws -> [String] {
        self.lock.withLock { Array($0.buckets.keys).sorted() }
    }

    public func presignedURL(bucket: String, key: String, expirySeconds: Int) async throws -> URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "fake.s3.example"
        comps.path = "/\(bucket)/\(key)"
        comps.queryItems = [URLQueryItem(name: "X-Amz-Expires", value: "\(expirySeconds)")]
        guard let url = comps.url else {
            throw StevedoreError.unsupported("URL construction failed for \(bucket)/\(key)")
        }
        return url
    }

    // MARK: - Inspection

    public func object(bucket: String, key: String) -> Data? {
        self.lock.withLock { $0.buckets[bucket]?[key] }
    }

    public func addBucket(_ name: String) {
        self.lock.withLock { state in
            if state.buckets[name] == nil { state.buckets[name] = [:] }
        }
    }
}
