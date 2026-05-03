import Core
@testable import FileSystemRemote
import XCTest

final class FTPProviderTests: XCTestCase, FileSystemProviderConformanceSuite {
    // MARK: - FileSystemProviderConformanceSuite

    var expectedScheme: ConnectionScheme {
        .ftp
    }

    var rootPath: FilePath {
        FilePath(scheme: .ftp, posix: "/")
    }

    var existingFilePath: FilePath {
        FilePath(scheme: .ftp, posix: "/readme.txt")
    }

    func makeProvider() async throws -> any FileSystemProvider {
        let transport = FakeFTPTransport(
            files: ["/readme.txt": Data("hello".utf8)],
            directories: ["/docs"]
        )
        let session = RemoteSession<any FTPTransport> { transport }
        return FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "localhost", port: 21),
            session: session
        )
    }

    func testConformanceSuite() async throws {
        try await runConformanceTests()
    }

    // MARK: - MLSD preference

    func testPrefersMLSDOverLIST() async throws {
        let transport = FakeFTPTransport(
            files: ["/file.txt": Data("x".utf8)],
            mlsdSupported: true
        )
        let session = RemoteSession<any FTPTransport> { transport }
        let provider = FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21),
            session: session
        )
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: self.rootPath, options: EnumerationOptions()) {
            items.append(item)
        }
        XCTAssertFalse(items.isEmpty)
    }

    func testFallsBackToLISTWhenMLSDUnsupported() async throws {
        let transport = FakeFTPTransport(
            files: ["/file.txt": Data("x".utf8)],
            mlsdSupported: false
        )
        let session = RemoteSession<any FTPTransport> { transport }
        let provider = FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21),
            session: session
        )
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: self.rootPath, options: EnumerationOptions()) {
            items.append(item)
        }
        XCTAssertFalse(items.isEmpty, "LIST fallback must yield items")
    }

    // MARK: - Execute mkdir

    func testMkdir() async throws {
        let transport = FakeFTPTransport()
        let session = RemoteSession<any FTPTransport> { transport }
        let provider = FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21),
            session: session
        )
        let dest = FilePath(scheme: .ftp, posix: "/newdir")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: dest)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
    }

    // MARK: - Execute delete

    func testDelete() async throws {
        let transport = FakeFTPTransport(files: ["/todelete.txt": Data("x".utf8)])
        let session = RemoteSession<any FTPTransport> { transport }
        let provider = FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21),
            session: session
        )
        let src = FilePath(scheme: .ftp, posix: "/todelete.txt")
        let op = OperationDescriptor(kind: .delete, sources: [src], destination: nil)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertNil(transport.file(at: "/todelete.txt"))
    }

    // MARK: - Execute rename

    func testRename() async throws {
        let transport = FakeFTPTransport(files: ["/old.txt": Data("data".utf8)])
        let session = RemoteSession<any FTPTransport> { transport }
        let provider = FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21),
            session: session
        )
        let src = FilePath(scheme: .ftp, posix: "/old.txt")
        let dst = FilePath(scheme: .ftp, posix: "/new.txt")
        let op = OperationDescriptor(kind: .rename, sources: [src], destination: dst)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertNotNil(transport.file(at: "/new.txt"))
    }

    // MARK: - Hidden files

    func testHiddenFilesExcludedByDefault() async throws {
        let transport = FakeFTPTransport(files: [
            "/visible.txt": Data("v".utf8),
            "/.hidden": Data("h".utf8),
        ])
        let session = RemoteSession<any FTPTransport> { transport }
        let provider = FTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21),
            session: session
        )
        let opts = EnumerationOptions(includesHiddenFiles: false)
        var names: [String] = []
        for try await item in provider.enumerate(at: self.rootPath, options: opts) {
            names.append(item.displayName)
        }
        XCTAssertFalse(names.contains(".hidden"))
        XCTAssertTrue(names.contains("visible.txt"))
    }
}
