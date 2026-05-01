import Core
@testable import FileSystemArchive
import Foundation
import XCTest

final class ArchivePathTraversalTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        self.tmp = try makeTempDir(label: "TraversalTests")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmp)
    }

    // MARK: - ZIP traversal

    func testMaliciousZipTraversalRejectedOnList() async throws {
        let archiveURL = try await Fixtures.maliciousZipFixture(at: self.tmp)
        let backend = ZipBackend()
        do {
            _ = try await backend.listEntries(at: archiveURL)
            XCTFail("expected traversal rejection")
        } catch StevedoreError.archive(.corruptedEntry) {
            // expected
        }
    }

    func testMaliciousZipLeavesTargetEmpty() async throws {
        let archiveURL = try await Fixtures.maliciousZipFixture(at: self.tmp)
        let targetURL = self.tmp.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)

        let extractor = ArchiveExtractor()
        do {
            _ = try await extractor.extract(archive: archiveURL, to: targetURL)
            XCTFail("expected traversal rejection")
        } catch StevedoreError.archive(.corruptedEntry) {
            // expected
        }

        let contents = try FileManager.default.contentsOfDirectory(atPath: targetURL.path)
        XCTAssertTrue(contents.isEmpty, "target dir must be empty after traversal rejection, found: \(contents)")
    }

    // MARK: - Tar traversal

    func testMaliciousTarListContainsTraversalPath() async throws {
        let archiveURL = try await Fixtures.maliciousTarFixture(at: self.tmp)
        let backend = try TarBackend(format: .tar)
        // The raw listing from /usr/bin/tar may include the bad path.
        // Our listEntries must reject it.
        do {
            _ = try await backend.listEntries(at: archiveURL)
            XCTFail("expected traversal rejection")
        } catch StevedoreError.archive(.corruptedEntry(let detail)) {
            XCTAssertTrue(
                detail.contains("traversal") || detail.contains(".."),
                "unexpected detail: \(detail)"
            )
        }
    }

    func testMaliciousTarLeavesTargetEmpty() async throws {
        let archiveURL = try await Fixtures.maliciousTarFixture(at: self.tmp)
        let targetURL = self.tmp.appendingPathComponent("tar-out", isDirectory: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)

        let extractor = ArchiveExtractor()
        do {
            _ = try await extractor.extract(archive: archiveURL, to: targetURL)
            XCTFail("expected traversal rejection")
        } catch StevedoreError.archive(.corruptedEntry) {
            // expected
        }

        let contents = try FileManager.default.contentsOfDirectory(atPath: targetURL.path)
        XCTAssertTrue(contents.isEmpty, "target dir must be empty after tar traversal rejection, found: \(contents)")
    }

    // MARK: - validateAndSplitEntryPath unit tests

    func testValidPathAccepted() throws {
        let components = try validateAndSplitEntryPath("dir/file.txt")
        XCTAssertEqual(components, ["dir", "file.txt"])
    }

    func testDotDotRejected() {
        XCTAssertThrowsError(try validateAndSplitEntryPath("../escape.txt"))
    }

    func testAbsolutePathRejected() {
        XCTAssertThrowsError(try validateAndSplitEntryPath("/abs/path.txt"))
    }

    func testTildeRejected() {
        XCTAssertThrowsError(try validateAndSplitEntryPath("~/file"))
    }

    func testEmbeddedDotDotRejected() {
        XCTAssertThrowsError(try validateAndSplitEntryPath("a/../b"))
    }
}
