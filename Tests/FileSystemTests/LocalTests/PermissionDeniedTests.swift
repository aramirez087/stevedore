import Core
import FileSystemLocal
import Foundation
import XCTest

final class PermissionDeniedTests: XCTestCase {
    private var fixture = TempDirectoryFixture()

    override func setUp() async throws {
        self.fixture = TempDirectoryFixture()
        try self.fixture.setUp()
    }

    override func tearDown() async throws {
        // Restore permissions so tearDown can actually delete the tree.
        try? FileManager().setAttributes([.posixPermissions: 0o755], ofItemAtPath: self.fixture.url.path)
        self.fixture.tearDown()
    }

    func testEnumeratePermissionDenied() async throws {
        // chmod 0o000 the fixture directory so we cannot list it.
        try FileManager().setAttributes([.posixPermissions: 0o000], ofItemAtPath: self.fixture.url.path)

        let provider = LocalFileSystemProvider()
        do {
            for try await _ in provider.enumerate(at: self.fixture.path, options: .default) {}
            XCTFail("Expected permissionDenied error")
        } catch let error as StevedoreError {
            guard case .fileSystem(.permissionDenied) = error else {
                XCTFail("Expected .fileSystem(.permissionDenied), got \(error)")
                return
            }
        }
    }

    func testAttributesPermissionDenied() async throws {
        let locked = try fixture.makeSubdirectory(name: "locked")
        try FileManager().setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        addTeardownBlock {
            try? FileManager().setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
        }
        // Try to read attributes of a file inside the locked directory.
        let inside = FilePath(scheme: .local, posix: locked.appendingPathComponent("x.txt").path)
        let provider = LocalFileSystemProvider()
        do {
            _ = try await provider.attributes(at: inside)
            XCTFail("Expected error")
        } catch let error as StevedoreError {
            // Accept either notFound or permissionDenied — macOS may report either
            // depending on whether the kernel reveals the name at all.
            switch error {
            case .fileSystem(.permissionDenied), .fileSystem(.notFound): break
            default: XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
