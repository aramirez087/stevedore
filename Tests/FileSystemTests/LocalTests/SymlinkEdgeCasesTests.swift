import Core
import FileSystemLocal
import Foundation
import XCTest

final class SymlinkEdgeCasesTests: XCTestCase {
    private var fixture = TempDirectoryFixture()

    override func setUp() async throws {
        self.fixture = TempDirectoryFixture()
        try self.fixture.setUp()
    }

    override func tearDown() async throws {
        self.fixture.tearDown()
    }

    func testBrokenSymlinkIsEnumerated() async throws {
        let linkURL = self.fixture.url.appendingPathComponent("broken.lnk")
        try FileManager().createSymbolicLink(
            atPath: linkURL.path,
            withDestinationPath: self.fixture.url.appendingPathComponent("nonexistent").path
        )

        let options = EnumerationOptions(includesHiddenFiles: true, isRecursive: false, followsSymbolicLinks: false)
        let provider = LocalFileSystemProvider()
        var found: FileItem?
        for try await item in provider.enumerate(at: self.fixture.path, options: options)
            where item.path.lastComponent == "broken.lnk" {
            found = item
        }
        XCTAssertNotNil(found, "Broken symlink should appear in enumeration")
        XCTAssertEqual(found?.kind, .symbolicLink)
    }

    func testSymlinkAttributesReadable() async throws {
        let targetURL = try fixture.makeFile(name: "target.txt", content: "hello")
        let linkURL = self.fixture.url.appendingPathComponent("link.txt")
        try FileManager().createSymbolicLink(atPath: linkURL.path, withDestinationPath: targetURL.path)

        let linkPath = FilePath(scheme: .local, posix: linkURL.path)
        let provider = LocalFileSystemProvider()
        let attrs = try await provider.attributes(at: linkPath)
        XCTAssertTrue(attrs.isSymbolicLink)
        XCTAssertNotNil(attrs.symbolicLinkTarget)
    }

    func testFollowSymlinksToggle() async throws {
        // Create a separate temp root that is only reachable via a symlink.
        let externalRoot = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager().createDirectory(at: externalRoot, withIntermediateDirectories: true)
        defer { try? FileManager().removeItem(at: externalRoot) }
        try "x".write(to: externalRoot.appendingPathComponent("only_via_link.txt"), atomically: true, encoding: .utf8)

        let linkURL = self.fixture.url.appendingPathComponent("link_to_external")
        try FileManager().createSymbolicLink(atPath: linkURL.path, withDestinationPath: externalRoot.path)

        // Without follow: symlink appears but its children (only_via_link.txt) do not.
        let noFollow = EnumerationOptions(includesHiddenFiles: false, isRecursive: true, followsSymbolicLinks: false)
        let provider = LocalFileSystemProvider()
        var names: [String] = []
        for try await item in provider.enumerate(at: self.fixture.path, options: noFollow) {
            names.append(item.path.lastComponent ?? "")
        }
        XCTAssertFalse(names.contains("only_via_link.txt"), "items inside symlinked dir should not appear")
        XCTAssertTrue(names.contains("link_to_external"), "symlink itself should appear")
    }
}
