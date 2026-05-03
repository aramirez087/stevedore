import Core
@testable import FileSystemArchive
import Foundation
import XCTest

final class ArchiveDetectorTests: XCTestCase {
    // MARK: - Extension detection

    func testZipExtension() {
        XCTAssertEqual(ArchiveDetector.detectByExtension("archive.zip"), .zip)
    }

    func testTarExtension() {
        XCTAssertEqual(ArchiveDetector.detectByExtension("archive.tar"), .tar)
    }

    func testTarGzExtensions() {
        XCTAssertEqual(ArchiveDetector.detectByExtension("archive.tar.gz"), .tarGzip)
        XCTAssertEqual(ArchiveDetector.detectByExtension("archive.tgz"), .tarGzip)
    }

    func testTarBz2Extensions() {
        XCTAssertEqual(ArchiveDetector.detectByExtension("archive.tar.bz2"), .tarBzip2)
        XCTAssertEqual(ArchiveDetector.detectByExtension("archive.tbz2"), .tarBzip2)
    }

    func testUnknownExtensionReturnsNil() {
        XCTAssertNil(ArchiveDetector.detectByExtension("document.pdf"))
        XCTAssertNil(ArchiveDetector.detectByExtension("script.sh"))
        XCTAssertNil(ArchiveDetector.detectByExtension(""))
    }

    func testUppercaseExtension() {
        XCTAssertEqual(ArchiveDetector.detectByExtension("ARCHIVE.ZIP"), .zip)
    }

    // MARK: - Magic bytes detection

    func testZipMagic() {
        let data = Data([0x50, 0x4B, 0x03, 0x04]) + Data(repeating: 0, count: 260)
        XCTAssertEqual(ArchiveDetector.detectByMagic(data), .zip)
    }

    func testGzipMagic() {
        let data = Data([0x1F, 0x8B]) + Data(repeating: 0, count: 262)
        XCTAssertEqual(ArchiveDetector.detectByMagic(data), .tarGzip)
    }

    func testBzip2Magic() {
        let data = Data([0x42, 0x5A, 0x68]) + Data(repeating: 0, count: 261)
        XCTAssertEqual(ArchiveDetector.detectByMagic(data), .tarBzip2)
    }

    func testUstarMagic() {
        var data = Data(repeating: 0, count: 264)
        // Write "ustar" at offset 257.
        data[257] = 0x75
        data[258] = 0x73
        data[259] = 0x74
        data[260] = 0x61
        data[261] = 0x72
        XCTAssertEqual(ArchiveDetector.detectByMagic(data), .tar)
    }

    func testUnknownMagicReturnsNil() {
        XCTAssertNil(ArchiveDetector.detectByMagic(Data("Hello, world!".utf8)))
    }

    func testTooShortMagicReturnsNil() {
        XCTAssertNil(ArchiveDetector.detectByMagic(Data([0x50])))
    }

    // MARK: - isArchive(_:)

    func testIsArchiveForZipURL() async throws {
        let tmp = try makeTempDir(label: "DetectorTests")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let archiveURL = try await Fixtures.zipFixture(at: tmp)
        let result = await ArchiveDetector.isArchive(archiveURL)
        XCTAssertTrue(result)
    }

    func testIsArchiveForPlainTextURL() async throws {
        let tmp = try makeTempDir(label: "DetectorTests")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let textURL = tmp.appendingPathComponent("plain.txt")
        try Data("plain text".utf8).write(to: textURL)
        let result = await ArchiveDetector.isArchive(textURL)
        XCTAssertFalse(result)
    }
}
