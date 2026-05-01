import Core
@testable import FileSystemRemote
import XCTest

final class S3ProviderTests: XCTestCase, FileSystemProviderConformanceSuite {
    // MARK: - FileSystemProviderConformanceSuite

    var expectedScheme: ConnectionScheme {
        .s3
    }

    var rootPath: FilePath {
        FilePath.root(.s3)
    }

    var existingFilePath: FilePath {
        FilePath(scheme: .s3, posix: "/mybucket/readme.txt")
    }

    func makeProvider() async throws -> any FileSystemProvider {
        let transport = FakeS3Transport(buckets: [
            "mybucket": ["readme.txt": Data("hello".utf8)],
        ])
        let session = RemoteSession<any S3Transport> { transport }
        return S3Provider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.amazonaws.com", port: 443),
            session: session
        )
    }

    func testConformanceSuite() async throws {
        try await runConformanceTests()
    }

    // MARK: - Root enumeration (list buckets)

    func testRootEnumeratesAllBuckets() async throws {
        let transport = FakeS3Transport(buckets: [
            "bucket-a": [:],
            "bucket-b": [:],
        ])
        let session = RemoteSession<any S3Transport> { transport }
        let provider = S3Provider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.amazonaws.com", port: 443),
            session: session
        )
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: self.rootPath, options: EnumerationOptions()) {
            items.append(item)
        }
        let names = items.map(\.displayName)
        XCTAssertTrue(names.contains("bucket-a"))
        XCTAssertTrue(names.contains("bucket-b"))
    }

    // MARK: - Bucket enumeration

    func testBucketEnumeratesObjects() async throws {
        let transport = FakeS3Transport(buckets: [
            "testbucket": [
                "notes.txt": Data("n".utf8),
                "photo.jpg": Data("p".utf8),
            ],
        ])
        let session = RemoteSession<any S3Transport> { transport }
        let provider = S3Provider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.amazonaws.com", port: 443),
            session: session
        )
        let bucketPath = FilePath(scheme: .s3, posix: "/testbucket")
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: bucketPath, options: EnumerationOptions()) {
            items.append(item)
        }
        XCTAssertFalse(items.isEmpty)
    }

    // MARK: - Attributes

    func testAttributesForObject() async throws {
        let anyProvider = try await makeProvider()
        let provider = try XCTUnwrap(anyProvider as? S3Provider)
        let attrs = try await provider.attributes(at: self.existingFilePath)
        XCTAssertEqual(attrs.sizeInBytes, 5) // "hello".count
    }

    func testAttributesForBucketDoesNotThrow() async throws {
        let anyProvider = try await makeProvider()
        let provider = try XCTUnwrap(anyProvider as? S3Provider)
        let bucketPath = FilePath(scheme: .s3, posix: "/mybucket")
        _ = try await provider.attributes(at: bucketPath)
    }

    // MARK: - Execute mkdir (virtual dir)

    func testMkdirCreatesVirtualDirectory() async throws {
        let transport = FakeS3Transport(buckets: ["bucket": [:]])
        let session = RemoteSession<any S3Transport> { transport }
        let provider = S3Provider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.amazonaws.com", port: 443),
            session: session
        )
        let dest = FilePath(scheme: .s3, posix: "/bucket/newdir")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: dest)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        // S3 mkdir creates a zero-byte object with trailing slash
        XCTAssertNotNil(transport.object(bucket: "bucket", key: "newdir/"))
    }

    // MARK: - Execute delete

    func testDelete() async throws {
        let transport = FakeS3Transport(buckets: ["bucket": ["file.txt": Data("x".utf8)]])
        let session = RemoteSession<any S3Transport> { transport }
        let provider = S3Provider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.amazonaws.com", port: 443),
            session: session
        )
        let src = FilePath(scheme: .s3, posix: "/bucket/file.txt")
        let op = OperationDescriptor(kind: .delete, sources: [src], destination: nil)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertNil(transport.object(bucket: "bucket", key: "file.txt"))
    }

    // MARK: - Execute rename (copy + delete)

    func testRename() async throws {
        let transport = FakeS3Transport(buckets: ["bucket": ["old.txt": Data("data".utf8)]])
        let session = RemoteSession<any S3Transport> { transport }
        let provider = S3Provider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.amazonaws.com", port: 443),
            session: session
        )
        let src = FilePath(scheme: .s3, posix: "/bucket/old.txt")
        let dst = FilePath(scheme: .s3, posix: "/bucket/new.txt")
        let op = OperationDescriptor(kind: .rename, sources: [src], destination: dst)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertNotNil(transport.object(bucket: "bucket", key: "new.txt"))
        XCTAssertNil(transport.object(bucket: "bucket", key: "old.txt"),
                     "original must be deleted after rename")
    }

    // MARK: - Root attributes

    func testRootAttributesDoNotThrow() async throws {
        let anyProvider = try await makeProvider()
        let provider = try XCTUnwrap(anyProvider as? S3Provider)
        _ = try await provider.attributes(at: self.rootPath)
    }
}
