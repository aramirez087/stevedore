import Core
import Foundation
import NIO
import NIOHTTP1
import SotoCore
import SotoS3

/// Soto-backed S3 transport.
///
/// `AWSClient` uses the shared HTTP client (no explicit teardown required for
/// the MVP). The `AWSClient` is deallocated naturally when this transport is
/// released; the shared HTTP client continues to serve other sessions.
///
/// Thread safety: `S3` (AWSService: Sendable) and `AWSClient` (Sendable) both
/// handle their own concurrency. This class holds only Sendable state.
public final class SotoS3Transport: S3Transport, Sendable {
    private let s3: S3
    private let awsClient: AWSClient

    public init(auth: RemoteAuthStrategy, region: String, endpoint: String? = nil) {
        let credentialProvider: CredentialProviderFactory = if case .awsSig4(let keyID, let secret, _) = auth {
            .static(accessKeyId: keyID, secretAccessKey: secret)
        } else {
            .default
        }
        let client = AWSClient(credentialProvider: credentialProvider)
        self.awsClient = client
        self.s3 = S3(
            client: client,
            region: Region(rawValue: region),
            endpoint: endpoint
        )
    }

    // MARK: - S3Transport

    public func listObjects(
        bucket: String,
        prefix: String?,
        delimiter: String?,
        continuationToken: String?
    ) async throws -> S3ListPage {
        do {
            let output = try await s3.listObjectsV2(
                bucket: bucket,
                continuationToken: continuationToken,
                delimiter: delimiter,
                prefix: prefix
            )
            let objects = (output.contents ?? []).map { obj in
                S3Object(
                    key: obj.key ?? "",
                    bucket: bucket,
                    sizeInBytes: obj.size,
                    lastModified: obj.lastModified,
                    etag: obj.eTag,
                    isDirectory: (obj.key ?? "").hasSuffix("/")
                )
            }
            let prefixes = (output.commonPrefixes ?? []).compactMap(\.prefix)
            return S3ListPage(objects: objects, prefixes: prefixes, nextToken: output.nextContinuationToken)
        } catch {
            throw self.mapError(error)
        }
    }

    public func headObject(bucket: String, key: String) async throws -> S3Object {
        do {
            let output = try await s3.headObject(bucket: bucket, key: key)
            return S3Object(
                key: key,
                bucket: bucket,
                sizeInBytes: output.contentLength,
                lastModified: output.lastModified,
                etag: output.eTag
            )
        } catch {
            throw self.mapError(error)
        }
    }

    public func getObject(bucket: String, key: String) -> AsyncThrowingStream<Data, any Error> {
        let s3 = self.s3
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let output = try await s3.getObject(bucket: bucket, key: key)
                    for try await buffer in output.body {
                        try Task.checkCancellation()
                        continuation.yield(Data(buffer.readableBytesView))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func putObject(
        bucket: String,
        key: String,
        data: Data,
        contentType: String?
    ) async throws {
        do {
            _ = try await self.s3.putObject(
                body: AWSHTTPBody(bytes: data),
                bucket: bucket,
                contentType: contentType,
                key: key
            )
        } catch {
            throw self.mapError(error)
        }
    }

    public func putObjectMultipart(
        bucket: String,
        key: String,
        data: AsyncThrowingStream<Data, any Error>,
        contentType: String?
    ) async throws {
        do {
            let createOutput = try await s3.createMultipartUpload(
                bucket: bucket,
                contentType: contentType,
                key: key
            )
            guard let uploadID = createOutput.uploadId else {
                throw StevedoreError.remote(.connectionFailed(detail: "No upload ID returned"))
            }

            var parts: [S3.CompletedPart] = []
            var partNumber = 1
            let partSize = 8 * 1024 * 1024
            var buffer = Data()

            func uploadBuffer() async throws {
                guard !buffer.isEmpty else { return }
                let partData = buffer
                let output = try await s3.uploadPart(
                    body: AWSHTTPBody(bytes: partData),
                    bucket: bucket,
                    contentLength: Int64(partData.count),
                    key: key,
                    partNumber: partNumber,
                    uploadId: uploadID
                )
                parts.append(S3.CompletedPart(eTag: output.eTag, partNumber: partNumber))
                partNumber += 1
                buffer = Data()
            }

            for try await chunk in data {
                buffer.append(chunk)
                if buffer.count >= partSize {
                    try await uploadBuffer()
                }
            }
            if !buffer.isEmpty {
                try await uploadBuffer()
            }

            _ = try await self.s3.completeMultipartUpload(
                bucket: bucket,
                key: key,
                multipartUpload: S3.CompletedMultipartUpload(parts: parts),
                uploadId: uploadID
            )
        } catch {
            throw self.mapError(error)
        }
    }

    public func deleteObject(bucket: String, key: String) async throws {
        do {
            _ = try await self.s3.deleteObject(bucket: bucket, key: key)
        } catch {
            throw self.mapError(error)
        }
    }

    public func listBuckets() async throws -> [String] {
        do {
            let output = try await s3.listBuckets()
            return (output.buckets ?? []).compactMap(\.name)
        } catch {
            throw self.mapError(error)
        }
    }

    public func presignedURL(bucket: String, key: String, expirySeconds: Int) async throws -> URL {
        do {
            guard let baseURL = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)") else {
                throw StevedoreError.invalidArgument("Cannot build S3 URL for \(bucket)/\(key)")
            }
            return try await self.s3.signURL(
                url: baseURL,
                httpMethod: .GET,
                expires: .seconds(Int64(expirySeconds))
            )
        } catch {
            throw self.mapError(error)
        }
    }

    // MARK: - Error mapping

    private func mapError(_ error: any Error) -> any Error {
        if let stevedoreError = error as? StevedoreError { return stevedoreError }
        return StevedoreError.remote(.connectionFailed(detail: error.localizedDescription))
    }
}
