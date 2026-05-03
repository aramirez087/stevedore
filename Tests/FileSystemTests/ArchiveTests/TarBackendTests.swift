import Core
@testable import FileSystemArchive
import Foundation
import XCTest

final class TarBackendTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        self.tmp = try makeTempDir(label: "TarBackendTests")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmp)
    }

    func testListTarEntries() async throws {
        let archiveURL = try await Fixtures.tarFixture(format: .tar, at: self.tmp)
        let backend = try TarBackend(format: .tar)
        let entries = try await backend.listEntries(at: archiveURL)
        let paths = Set(entries.map(\.relativePath))
        XCTAssertTrue(paths.contains("a.txt") || paths.contains("./a.txt"))
    }

    func testExtractTar() async throws {
        let archiveURL = try await Fixtures.tarFixture(format: .tar, at: self.tmp)
        let destURL = self.tmp.appendingPathComponent("out-tar", isDirectory: true)
        try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
        let backend = try TarBackend(format: .tar)
        try await backend.extractAll(from: archiveURL, to: destURL, progress: nil)
        let extracted = try FileManager.default.contentsOfDirectory(
            at: destURL, includingPropertiesForKeys: nil, options: []
        )
        XCTAssertFalse(extracted.isEmpty, "no files extracted from tar")
    }

    func testExtractTarGz() async throws {
        let archiveURL = try await Fixtures.tarFixture(format: .tarGzip, at: self.tmp)
        let destURL = self.tmp.appendingPathComponent("out-tgz", isDirectory: true)
        try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
        let backend = try TarBackend(format: .tarGzip)
        try await backend.extractAll(from: archiveURL, to: destURL, progress: nil)
        let extracted = try FileManager.default.contentsOfDirectory(
            at: destURL, includingPropertiesForKeys: nil, options: []
        )
        XCTAssertFalse(extracted.isEmpty, "no files extracted from tar.gz")
    }

    func testExtractTarBz2() async throws {
        let archiveURL = try await Fixtures.tarFixture(format: .tarBzip2, at: self.tmp)
        let destURL = self.tmp.appendingPathComponent("out-tbz2", isDirectory: true)
        try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
        let backend = try TarBackend(format: .tarBzip2)
        try await backend.extractAll(from: archiveURL, to: destURL, progress: nil)
        let extracted = try FileManager.default.contentsOfDirectory(
            at: destURL, includingPropertiesForKeys: nil, options: []
        )
        XCTAssertFalse(extracted.isEmpty, "no files extracted from tar.bz2")
    }

    func testInvalidFormatThrows() {
        XCTAssertThrowsError(try TarBackend(format: .zip))
    }
}
