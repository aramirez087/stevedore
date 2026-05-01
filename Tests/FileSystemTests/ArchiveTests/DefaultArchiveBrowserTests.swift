import Core
@testable import FileSystemArchive
import Foundation
import XCTest

final class DefaultArchiveBrowserTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        self.tmp = try makeTempDir(label: "BrowserTests")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmp)
    }

    func testIsArchiveTrueForZip() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let browser = DefaultArchiveBrowser()
        let path = FilePath(scheme: .local, posix: archiveURL.path)
        let result = await browser.isArchive(path)
        XCTAssertTrue(result)
    }

    func testIsArchiveFalseForPlainText() async throws {
        let textURL = self.tmp.appendingPathComponent("plain.txt")
        try Data("hello".utf8).write(to: textURL)
        let browser = DefaultArchiveBrowser()
        let path = FilePath(scheme: .local, posix: textURL.path)
        let result = await browser.isArchive(path)
        XCTAssertFalse(result)
    }

    func testIsArchiveFalseForNonLocalPath() async {
        let browser = DefaultArchiveBrowser()
        let path = FilePath(scheme: .sftp, posix: "/archive.zip")
        let result = await browser.isArchive(path)
        XCTAssertFalse(result)
    }

    func testEntriesReturnsSortedFileItems() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let browser = DefaultArchiveBrowser()
        let path = FilePath(scheme: .local, posix: archiveURL.path)
        let entries = try await browser.entries(in: path)
        XCTAssertFalse(entries.isEmpty)
        // Entries must be sorted by posixString.
        let paths = entries.map(\.path.posixString)
        XCTAssertEqual(paths, paths.sorted())
    }

    func testEntriesThrowsForNonArchive() async throws {
        let textURL = self.tmp.appendingPathComponent("plain.txt")
        try Data("hello".utf8).write(to: textURL)
        let browser = DefaultArchiveBrowser()
        let path = FilePath(scheme: .local, posix: textURL.path)
        do {
            _ = try await browser.entries(in: path)
            XCTFail("expected unsupportedFormat error")
        } catch StevedoreError.archive(.unsupportedFormat) {
            // expected
        }
    }

    func testEntriesThrowsForNonLocalScheme() async throws {
        let browser = DefaultArchiveBrowser()
        let path = FilePath(scheme: .sftp, posix: "/archive.zip")
        do {
            _ = try await browser.entries(in: path)
            XCTFail("expected unsupported error")
        } catch StevedoreError.unsupported {
            // expected
        }
    }
}
