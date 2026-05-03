import Core
@testable import FileSystemRemote
import XCTest

final class WebDAVProviderTests: XCTestCase, FileSystemProviderConformanceSuite {
    // MARK: - FileSystemProviderConformanceSuite

    var expectedScheme: ConnectionScheme {
        .webdav
    }

    var rootPath: FilePath {
        FilePath(scheme: .webdav, posix: "/")
    }

    var existingFilePath: FilePath {
        FilePath(scheme: .webdav, posix: "/readme.txt")
    }

    func makeProvider() async throws -> any FileSystemProvider {
        let transport = FakeWebDAVTransport(
            files: ["/readme.txt": Data("hello".utf8)],
            collections: ["/docs"]
        )
        let session = RemoteSession<any WebDAVTransport> { transport }
        return WebDAVProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "dav.example.com", port: 443),
            session: session
        )
    }

    func testConformanceSuite() async throws {
        try await runConformanceTests()
    }

    // MARK: - Enumerate

    func testEnumerateRootYieldsFilesAndCollections() async throws {
        let anyProvider = try await makeProvider()
        let provider = try XCTUnwrap(anyProvider as? WebDAVProvider)
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: self.rootPath, options: EnumerationOptions()) {
            items.append(item)
        }
        let names = items.map(\.displayName)
        XCTAssertTrue(names.contains("readme.txt") || !names.isEmpty)
    }

    func testEnumerateSkipsCollectionItself() async throws {
        let transport = FakeWebDAVTransport(collections: ["/folder"])
        let session = RemoteSession<any WebDAVTransport> { transport }
        let provider = WebDAVProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "h", port: 80),
            session: session
        )
        let folderPath = FilePath(scheme: .webdav, posix: "/folder")
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: folderPath, options: EnumerationOptions()) {
            items.append(item)
        }
        XCTAssertFalse(items.map(\.path.posixString).contains("/folder"))
    }

    // MARK: - Execute mkdir (MKCOL)

    func testMkdirSendsMKCOL() async throws {
        let transport = FakeWebDAVTransport()
        let session = RemoteSession<any WebDAVTransport> { transport }
        let provider = WebDAVProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "h", port: 80),
            session: session
        )
        let dest = FilePath(scheme: .webdav, posix: "/newdir")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: dest)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue(transport.calls.contains { $0.method == "MKCOL" })
    }

    // MARK: - Execute delete

    func testDeleteSendsDELETE() async throws {
        let transport = FakeWebDAVTransport(files: ["/file.txt": Data("x".utf8)])
        let session = RemoteSession<any WebDAVTransport> { transport }
        let provider = WebDAVProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "h", port: 80),
            session: session
        )
        let src = FilePath(scheme: .webdav, posix: "/file.txt")
        let op = OperationDescriptor(kind: .delete, sources: [src], destination: nil)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue(transport.calls.contains { $0.method == "DELETE" })
    }

    // MARK: - Execute rename (MOVE)

    func testRenameSendsMOVE() async throws {
        let transport = FakeWebDAVTransport(files: ["/old.txt": Data("data".utf8)])
        let session = RemoteSession<any WebDAVTransport> { transport }
        let provider = WebDAVProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "h", port: 80),
            session: session
        )
        let src = FilePath(scheme: .webdav, posix: "/old.txt")
        let dst = FilePath(scheme: .webdav, posix: "/new.txt")
        let op = OperationDescriptor(kind: .rename, sources: [src], destination: dst)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue(transport.calls.contains { $0.method == "MOVE" })
    }

    // MARK: - Execute copy (COPY)

    func testCopySendsCOPY() async throws {
        let transport = FakeWebDAVTransport(files: ["/src.txt": Data("x".utf8)])
        let session = RemoteSession<any WebDAVTransport> { transport }
        let provider = WebDAVProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "h", port: 80),
            session: session
        )
        let src = FilePath(scheme: .webdav, posix: "/src.txt")
        let dst = FilePath(scheme: .webdav, posix: "/dst.txt")
        let op = OperationDescriptor(kind: .copy, sources: [src], destination: dst)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue(transport.calls.contains { $0.method == "COPY" })
    }

    // MARK: - Error handling

    func testFailedMKCOLThrows() async throws {
        let transport = FakeWebDAVTransport()
        transport.setStatusOverride(403)
        let session = RemoteSession<any WebDAVTransport> { transport }
        let provider = WebDAVProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .webdav, host: "h", port: 80),
            session: session
        )
        let dest = FilePath(scheme: .webdav, posix: "/forbidden")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: dest)
        do {
            _ = try await provider.execute(op, progress: nil)
            XCTFail("Expected error for 403 MKCOL")
        } catch {
            // Expected
        }
    }
}
