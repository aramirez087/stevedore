import Core
@testable import FileSystemArchive
import Foundation
import XCTest

final class ZipBackendTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        self.tmp = try makeTempDir(label: "ZipBackendTests")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmp)
    }

    func testListEntries() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let backend = ZipBackend()
        let entries = try await backend.listEntries(at: archiveURL)
        let paths = Set(entries.map(\.relativePath))
        XCTAssertTrue(paths.contains("a.txt"))
        XCTAssertTrue(paths.contains("dir/b.txt"))
        XCTAssertTrue(paths.contains("dir/c.bin"))
    }

    func testModePreservation() async throws {
        // Create a zip with a file that has 0o755 mode.
        let srcURL = self.tmp.appendingPathComponent("exec.sh")
        try Data("#!/bin/sh\n".utf8).write(to: srcURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: srcURL.path)

        let archiveURL = self.tmp.appendingPathComponent("modes.zip")
        let creator = ArchiveCreator()
        try await creator.createZip(sources: [srcURL], relativeTo: self.tmp, archive: archiveURL)

        let backend = ZipBackend()
        let entries = try await backend.listEntries(at: archiveURL)
        guard let entry = entries.first(where: { $0.relativePath == "exec.sh" }) else {
            XCTFail("entry not found")
            return
        }
        XCTAssertNotNil(entry.permissions)
        // 0o755 = owner:7 group:5 other:5
        XCTAssertEqual(entry.permissions?.owner, 7)
        XCTAssertEqual(entry.permissions?.group, 5)
        XCTAssertEqual(entry.permissions?.other, 5)
    }

    func testMtimePreservation() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let backend = ZipBackend()
        let entries = try await backend.listEntries(at: archiveURL)
        for entry in entries where entry.kind == .regularFile {
            XCTAssertNotNil(entry.modificationDate, "mtime missing for \(entry.relativePath)")
        }
    }

    func testExtractEntry() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let destURL = self.tmp.appendingPathComponent("extracted_a.txt")
        let backend = ZipBackend()
        try await backend.extractEntry(at: "a.txt", from: archiveURL, to: destURL)
        let content = try Data(contentsOf: destURL)
        XCTAssertEqual(content, Data("hello world".utf8))
    }

    func testStreamRead() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let backend = ZipBackend()
        var accumulated = Data()
        for try await chunk in backend.streamRead(entryPath: "a.txt", from: archiveURL) {
            accumulated.append(chunk)
        }
        XCTAssertEqual(accumulated, Data("hello world".utf8))
    }
}
