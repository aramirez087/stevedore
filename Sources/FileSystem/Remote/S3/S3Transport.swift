import Foundation

/// A single object or virtual directory returned by an S3 listing.
public struct S3Object: Sendable, Hashable {
    public let key: String
    public let bucket: String
    public let sizeInBytes: Int64?
    public let lastModified: Date?
    public let etag: String?
    /// True when `key` ends with "/" (virtual directory prefix).
    public let isDirectory: Bool

    public init(
        key: String,
        bucket: String,
        sizeInBytes: Int64? = nil,
        lastModified: Date? = nil,
        etag: String? = nil,
        isDirectory: Bool = false
    ) {
        self.key = key
        self.bucket = bucket
        self.sizeInBytes = sizeInBytes
        self.lastModified = lastModified
        self.etag = etag
        self.isDirectory = isDirectory
    }
}

/// Paginated result from `listObjects`.
public struct S3ListPage: Sendable {
    public let objects: [S3Object]
    public let prefixes: [String]
    public let nextToken: String?

    public init(objects: [S3Object], prefixes: [String], nextToken: String?) {
        self.objects = objects
        self.prefixes = prefixes
        self.nextToken = nextToken
    }
}

/// Transport abstraction for Amazon S3. Soto-backed implementation is in
/// `SotoS3Transport`; fakes implement this protocol directly.
public protocol S3Transport: Sendable {
    func listObjects(
        bucket: String,
        prefix: String?,
        delimiter: String?,
        continuationToken: String?
    ) async throws -> S3ListPage

    func headObject(bucket: String, key: String) async throws -> S3Object
    func getObject(bucket: String, key: String) -> AsyncThrowingStream<Data, any Error>
    func putObject(bucket: String, key: String, data: Data, contentType: String?) async throws
    func putObjectMultipart(
        bucket: String,
        key: String,
        data: AsyncThrowingStream<Data, any Error>,
        contentType: String?
    ) async throws
    func deleteObject(bucket: String, key: String) async throws
    func listBuckets() async throws -> [String]
    func presignedURL(bucket: String, key: String, expirySeconds: Int) async throws -> URL
}
