import Core
@testable import FileSystemRemote
import XCTest

final class SFTPProviderTests: XCTestCase, FileSystemProviderConformanceSuite {
    // MARK: - FileSystemProviderConformanceSuite

    var expectedScheme: ConnectionScheme {
        .sftp
    }

    var rootPath: FilePath {
        FilePath(scheme: .sftp, posix: "/")
    }

    var existingFilePath: FilePath {
        FilePath(scheme: .sftp, posix: "/readme.txt")
    }

    func makeProvider() async throws -> any FileSystemProvider {
        let transport = FakeSFTPTransport(
            files: ["/readme.txt": Data("hello".utf8)],
            directories: ["/docs"]
        )
        let session = RemoteSession<any SFTPTransport> { transport }
        return SFTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "localhost", port: 22),
            session: session
        )
    }

    func testConformanceSuite() async throws {
        try await runConformanceTests()
    }

    // MARK: - Enumerate

    func testEnumerateListsFilesAndDirectories() async throws {
        let anyProvider = try await makeProvider()
        let provider = try XCTUnwrap(anyProvider as? SFTPProvider)
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: self.rootPath, options: EnumerationOptions()) {
            items.append(item)
        }
        let names = items.map(\.displayName)
        XCTAssertTrue(names.contains("readme.txt"))
        XCTAssertTrue(names.contains("docs"))
    }

    func testEnumerateHidesHiddenFilesByDefault() async throws {
        let transport = FakeSFTPTransport(files: [
            "/readme.txt": Data("hi".utf8),
            "/.hidden": Data("secret".utf8),
        ])
        let session = RemoteSession<any SFTPTransport> { transport }
        let provider = SFTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "h", port: 22),
            session: session
        )
        var items: [FileItem] = []
        let opts = EnumerationOptions(includesHiddenFiles: false)
        for try await item in provider.enumerate(at: self.rootPath, options: opts) {
            items.append(item)
        }
        XCTAssertFalse(items.map(\.displayName).contains(".hidden"))
    }

    // MARK: - Attributes

    func testAttributesForFile() async throws {
        let anyProvider = try await makeProvider()
        let provider = try XCTUnwrap(anyProvider as? SFTPProvider)
        let attrs = try await provider.attributes(at: self.existingFilePath)
        XCTAssertEqual(attrs.sizeInBytes, 5) // "hello".count
    }

    // MARK: - Execute mkdir

    func testMkdir() async throws {
        let transport = FakeSFTPTransport()
        let session = RemoteSession<any SFTPTransport> { transport }
        let provider = SFTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "h", port: 22),
            session: session
        )
        let dest = FilePath(scheme: .sftp, posix: "/newdir")
        let op = OperationDescriptor(kind: .mkdir, sources: [], destination: dest)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue(transport.hasDirectory("/newdir"))
    }

    // MARK: - Execute delete

    func testDelete() async throws {
        let transport = FakeSFTPTransport(files: ["/file.txt": Data("x".utf8)])
        let session = RemoteSession<any SFTPTransport> { transport }
        let provider = SFTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "h", port: 22),
            session: session
        )
        let src = FilePath(scheme: .sftp, posix: "/file.txt")
        let op = OperationDescriptor(kind: .delete, sources: [src], destination: nil)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertNil(transport.file(at: "/file.txt"))
    }

    // MARK: - Execute rename

    func testRename() async throws {
        let transport = FakeSFTPTransport(files: ["/old.txt": Data("data".utf8)])
        let session = RemoteSession<any SFTPTransport> { transport }
        let provider = SFTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "h", port: 22),
            session: session
        )
        let src = FilePath(scheme: .sftp, posix: "/old.txt")
        let dst = FilePath(scheme: .sftp, posix: "/new.txt")
        let op = OperationDescriptor(kind: .rename, sources: [src], destination: dst)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertNotNil(transport.file(at: "/new.txt"))
        XCTAssertNil(transport.file(at: "/old.txt"))
    }

    // MARK: - Execute copy

    func testCopy() async throws {
        let transport = FakeSFTPTransport(files: ["/src.txt": Data("copied".utf8)])
        let session = RemoteSession<any SFTPTransport> { transport }
        let provider = SFTPProvider(
            descriptor: RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "h", port: 22),
            session: session
        )
        let src = FilePath(scheme: .sftp, posix: "/src.txt")
        let dst = FilePath(scheme: .sftp, posix: "/dst.txt")
        let op = OperationDescriptor(kind: .copy, sources: [src], destination: dst)
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(transport.file(at: "/dst.txt"), Data("copied".utf8))
        XCTAssertNotNil(transport.file(at: "/src.txt"), "source must still exist after copy")
    }
}
