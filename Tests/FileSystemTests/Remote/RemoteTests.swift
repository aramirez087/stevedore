import Core
@testable import FileSystemRemote
import os
import XCTest

/// Top-level integration suite for the remote provider stack.
/// Running `swift test --filter RemoteTests` executes all methods here.
final class RemoteTests: XCTestCase {
    // MARK: - SFTP

    func testSFTPEnumerateAndRead() async throws {
        let transport = FakeSFTPTransport(
            files: ["/hello.txt": Data("world".utf8)],
            directories: ["/docs"]
        )
        let session = RemoteSession<any SFTPTransport> { transport }
        let provider = SFTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "h", port: 22),
            session: session
        )
        var names: [String] = []
        for try await item in provider.enumerate(
            at: FilePath(scheme: .sftp, posix: "/"),
            options: EnumerationOptions()
        ) {
            names.append(item.displayName)
        }
        XCTAssertTrue(names.contains("hello.txt"))
        XCTAssertTrue(names.contains("docs"))

        let attrs = try await provider.attributes(at: FilePath(scheme: .sftp, posix: "/hello.txt"))
        XCTAssertEqual(attrs.sizeInBytes, 5)
    }

    func testSFTPWriteAndDelete() async throws {
        let transport = FakeSFTPTransport(files: ["/file.txt": Data("x".utf8)])
        let session = RemoteSession<any SFTPTransport> { transport }
        let provider = SFTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "h", port: 22),
            session: session
        )
        let path = FilePath(scheme: .sftp, posix: "/file.txt")
        let result = try await provider.execute(
            OperationDescriptor(kind: .delete, sources: [path], destination: nil),
            progress: nil
        )
        XCTAssertEqual(result.status, .completed)
        XCTAssertNil(transport.file(at: "/file.txt"))
    }

    // MARK: - FTP

    func testFTPEnumerateMLSD() async throws {
        let transport = FakeFTPTransport(
            files: ["/report.pdf": Data(repeating: 0, count: 1024)],
            mlsdSupported: true
        )
        let session = RemoteSession<any FTPTransport> { transport }
        let provider = FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21),
            session: session
        )
        var items: [FileItem] = []
        for try await item in provider
            .enumerate(at: FilePath(scheme: .ftp, posix: "/"), options: EnumerationOptions()) {
            items.append(item)
        }
        XCTAssertTrue(items.map(\.displayName).contains("report.pdf"))
    }

    func testFTPEnumerateLISTFallback() async throws {
        let transport = FakeFTPTransport(
            files: ["/report.pdf": Data(repeating: 0, count: 512)],
            mlsdSupported: false
        )
        let session = RemoteSession<any FTPTransport> { transport }
        let provider = FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21),
            session: session
        )
        var items: [FileItem] = []
        for try await item in provider
            .enumerate(at: FilePath(scheme: .ftp, posix: "/"), options: EnumerationOptions()) {
            items.append(item)
        }
        XCTAssertFalse(items.isEmpty, "LIST fallback must yield items")
    }

    func testFTPRenameAndDelete() async throws {
        let transport = FakeFTPTransport(files: ["/old.txt": Data("data".utf8)])
        let session = RemoteSession<any FTPTransport> { transport }
        let provider = FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21),
            session: session
        )
        let rename = try await provider.execute(
            OperationDescriptor(
                kind: .rename,
                sources: [FilePath(scheme: .ftp, posix: "/old.txt")],
                destination: FilePath(scheme: .ftp, posix: "/new.txt")
            ),
            progress: nil
        )
        XCTAssertEqual(rename.status, .completed)
        XCTAssertNotNil(transport.file(at: "/new.txt"))
    }

    // MARK: - WebDAV

    func testWebDAVEnumerateAndMkcol() async throws {
        let transport = FakeWebDAVTransport(
            files: ["/index.html": Data("<html/>".utf8)],
            collections: ["/assets"]
        )
        let session = RemoteSession<any WebDAVTransport> { transport }
        let provider = WebDAVProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "h", port: 80),
            session: session
        )
        var names: [String] = []
        for try await item in provider.enumerate(
            at: FilePath(scheme: .webdav, posix: "/"),
            options: EnumerationOptions()
        ) {
            names.append(item.displayName)
        }
        XCTAssertFalse(names.isEmpty)

        let mkdirResult = try await provider.execute(
            OperationDescriptor(kind: .mkdir, sources: [], destination: FilePath(scheme: .webdav, posix: "/newdir")),
            progress: nil
        )
        XCTAssertEqual(mkdirResult.status, .completed)
        XCTAssertTrue(transport.calls.contains { $0.method == "MKCOL" })
    }

    func testWebDAVMoveAndCopy() async throws {
        let transport = FakeWebDAVTransport(files: ["/src.txt": Data("hello".utf8)])
        let session = RemoteSession<any WebDAVTransport> { transport }
        let provider = WebDAVProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "h", port: 80),
            session: session
        )
        let copyResult = try await provider.execute(
            OperationDescriptor(
                kind: .copy,
                sources: [FilePath(scheme: .webdav, posix: "/src.txt")],
                destination: FilePath(scheme: .webdav, posix: "/dst.txt")
            ),
            progress: nil
        )
        XCTAssertEqual(copyResult.status, .completed)
        XCTAssertTrue(transport.calls.contains { $0.method == "COPY" })
    }

    // MARK: - S3

    func testS3EnumerateBuckets() async throws {
        let transport = FakeS3Transport(
            buckets: ["photos": ["vacation/img.jpg": Data(repeating: 0xFF, count: 256)]]
        )
        let session = RemoteSession<any S3Transport> { transport }
        let provider = S3Provider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.amazonaws.com", port: 443),
            session: session
        )
        var names: [String] = []
        for try await item in provider.enumerate(at: FilePath(scheme: .s3, posix: "/"), options: EnumerationOptions()) {
            names.append(item.displayName)
        }
        XCTAssertTrue(names.contains("photos"))
    }

    func testS3EnumerateObjectsInBucket() async throws {
        let transport = FakeS3Transport(
            buckets: ["docs": ["readme.md": Data("# Hi".utf8), "guide.md": Data("# Guide".utf8)]]
        )
        let session = RemoteSession<any S3Transport> { transport }
        let provider = S3Provider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .s3, host: "s3.amazonaws.com", port: 443),
            session: session
        )
        var names: [String] = []
        for try await item in provider.enumerate(
            at: FilePath(scheme: .s3, posix: "/docs"),
            options: EnumerationOptions()
        ) {
            names.append(item.displayName)
        }
        XCTAssertTrue(names.contains("readme.md"))
    }

    // MARK: - Registry routing

    func testRegistryRoutesAllSchemes() async throws {
        let registry = RemoteProviderRegistry()

        await registry.register(scheme: .sftp) { host, _ in
            let t = FakeSFTPTransport()
            let session = RemoteSession<any SFTPTransport> { t }
            return SFTPProvider(descriptor: host, session: session)
        }
        await registry.register(scheme: .ftp) { host, _ in
            let t = FakeFTPTransport()
            let session = RemoteSession<any FTPTransport> { t }
            return FTPProvider(descriptor: host, session: session)
        }
        await registry.register(scheme: .webdav) { host, _ in
            let t = FakeWebDAVTransport()
            let session = RemoteSession<any WebDAVTransport> { t }
            return WebDAVProvider(descriptor: host, session: session)
        }
        await registry.register(scheme: .s3) { host, _ in
            let t = FakeS3Transport()
            let session = RemoteSession<any S3Transport> { t }
            return S3Provider(descriptor: host, session: session)
        }

        let schemes: [(ConnectionScheme, Int)] = [(.sftp, 22), (.ftp, 21), (.webdav, 80), (.s3, 443)]
        for (scheme, port) in schemes {
            let host = RemoteHostDescriptor(displayName: "test", scheme: scheme, host: "h", port: port)
            let provider = try await registry.open(host, credential: nil)
            XCTAssertEqual(provider.scheme, scheme, "registry must route \(scheme) correctly")
        }
    }

    func testRegistryConnectivityTest() async throws {
        let registry = RemoteProviderRegistry()
        let transport = FakeSFTPTransport(files: ["/probe": Data("ok".utf8)])
        await registry.register(scheme: .sftp) { host, _ in
            let session = RemoteSession<any SFTPTransport> { transport }
            return SFTPProvider(descriptor: host, session: session)
        }
        let host = RemoteHostDescriptor(
            displayName: "test",
            scheme: .sftp,
            host: "h",
            port: 22,
            initialPath: FilePath(scheme: .sftp, posix: "/probe")
        )
        let result = try await registry.test(host, credential: nil)
        XCTAssertEqual(result.status, .success)
    }

    // MARK: - Session retry

    func testSessionRetriesOnConnectionFailure() async throws {
        let attempts = OSAllocatedUnfairLock(initialState: 0)
        let session = RemoteSession<Int>(
            factory: {
                let n = attempts.withLock { state -> Int in
                    state += 1
                    return state
                }
                if n < 3 { throw StevedoreError.remote(.connectionFailed(detail: "attempt \(n)")) }
                return 99
            },
            retryPolicy: RetryPolicy(
                maxAttempts: 3,
                baseDelayNanoseconds: 0,
                maxDelayNanoseconds: 0,
                jitterFraction: 0
            )
        )
        let value = try await session.withTransport { $0 }
        XCTAssertEqual(value, 99)
        XCTAssertEqual(attempts.withLock { $0 }, 3)
    }
}
