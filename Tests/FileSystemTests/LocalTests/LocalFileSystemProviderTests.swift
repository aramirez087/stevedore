import Core
import FileSystemLocal
import Foundation
import XCTest

final class LocalFileSystemProviderTests: XCTestCase {
    private var fixture = TempDirectoryFixture()

    override func setUp() async throws {
        self.fixture = TempDirectoryFixture()
        try self.fixture.setUp()
    }

    override func tearDown() async throws {
        self.fixture.tearDown()
    }

    // MARK: - Scheme

    func testSchemeIsLocal() {
        let provider = LocalFileSystemProvider()
        XCTAssertEqual(provider.scheme, .local)
    }

    // MARK: - Attributes

    func testAttributesRoundTripForRegularFile() async throws {
        let fileURL = try fixture.makeFile(name: "attr.txt", content: "hello world")
        let path = FilePath(scheme: .local, posix: fileURL.path)
        let provider = LocalFileSystemProvider()
        let attrs = try await provider.attributes(at: path)
        XCTAssertEqual(attrs.sizeInBytes, 11)
        XCTAssertNotNil(attrs.modificationDate)
        XCTAssertFalse(attrs.isSymbolicLink)
        XCTAssertFalse(attrs.isHidden)
    }

    func testAttributesForDirectoryReturnsDirectory() async throws {
        let provider = LocalFileSystemProvider()
        let attrs = try await provider.attributes(at: self.fixture.path)
        XCTAssertNotNil(attrs.modificationDate)
        XCTAssertFalse(attrs.isSymbolicLink)
    }

    func testAttributesForMissingPathThrowsNotFound() async throws {
        let provider = LocalFileSystemProvider()
        let missing = FilePath(scheme: .local, posix: fixture.url.appendingPathComponent("no-such").path)
        do {
            _ = try await provider.attributes(at: missing)
            XCTFail("Should throw")
        } catch let e as StevedoreError {
            guard case .fileSystem(.notFound) = e else {
                XCTFail("Expected .notFound, got \(e)")
                return
            }
        }
    }

    func testAttributesRejectsNonLocalPath() async throws {
        let provider = LocalFileSystemProvider()
        let remote = FilePath(scheme: .sftp, posix: "/home/user")
        do {
            _ = try await provider.attributes(at: remote)
            XCTFail("Should throw")
        } catch let e as StevedoreError {
            guard case .invalidArgument = e else {
                XCTFail("Expected .invalidArgument, got \(e)")
                return
            }
        }
    }

    // MARK: - Enumerate

    func testEnumerateRejectsNonLocalPath() async throws {
        let provider = LocalFileSystemProvider()
        let remote = FilePath(scheme: .sftp, posix: "/home/user")
        do {
            for try await _ in provider.enumerate(at: remote, options: .default) {}
            XCTFail("Should throw")
        } catch let e as StevedoreError {
            guard case .invalidArgument = e else {
                XCTFail("Expected .invalidArgument, got \(e)")
                return
            }
        }
    }

    // MARK: - Execute unsupported

    func testExecuteArchiveThrowsUnsupported() async throws {
        let provider = LocalFileSystemProvider()
        let op = OperationDescriptor(kind: .archive(format: .zip), sources: [fixture.path])
        do {
            _ = try await provider.execute(op, progress: nil)
            XCTFail("Should throw .unsupported")
        } catch let e as StevedoreError {
            guard case .unsupported = e else {
                XCTFail("Expected .unsupported, got \(e)")
                return
            }
        }
    }
}
