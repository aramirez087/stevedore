import Core
@testable import FileSystemArchive
import Foundation
import XCTest

final class ArchiveCreatorTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        self.tmp = try makeTempDir(label: "CreatorTests")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmp)
    }

    func testCreateZipFromNestedDirectory() async throws {
        let srcRoot = self.tmp.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: srcRoot, withIntermediateDirectories: true)
        _ = try Fixtures.seedDirectory(at: srcRoot)

        let archiveURL = self.tmp.appendingPathComponent("output.zip")
        let creator = ArchiveCreator()
        let size = try await creator.createZip(sources: [srcRoot], relativeTo: self.tmp, archive: archiveURL)

        XCTAssertGreaterThan(size, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
    }

    func testEntryListMatchesSources() async throws {
        let srcRoot = self.tmp.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: srcRoot, withIntermediateDirectories: true)
        _ = try Fixtures.seedDirectory(at: srcRoot)

        let archiveURL = self.tmp.appendingPathComponent("output.zip")
        let creator = ArchiveCreator()
        try await creator.createZip(sources: [srcRoot], relativeTo: self.tmp, archive: archiveURL)

        let backend = ZipBackend()
        let entries = try await backend.listEntries(at: archiveURL)
        let paths = Set(entries.map(\.relativePath))
        XCTAssertTrue(paths.contains(where: { $0.contains("a.txt") }))
        XCTAssertTrue(paths.contains(where: { $0.contains("b.txt") }))
        XCTAssertTrue(paths.contains(where: { $0.contains("c.bin") }))
    }

    func testRoundTripPreservesContent() async throws {
        let srcRoot = self.tmp.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: srcRoot, withIntermediateDirectories: true)
        _ = try Fixtures.seedDirectory(at: srcRoot)

        let archiveURL = self.tmp.appendingPathComponent("roundtrip.zip")
        let creator = ArchiveCreator()
        try await creator.createZip(sources: [srcRoot], relativeTo: self.tmp, archive: archiveURL)

        let destURL = self.tmp.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
        let extractor = ArchiveExtractor()
        _ = try await extractor.extract(archive: archiveURL, to: destURL)

        // Build a map of filename → Data for all files in the extracted tree.
        let allExtracted = self.allFiles(under: destURL)

        for (relativePath, originalData) in Fixtures.seedFiles {
            let filename = URL(fileURLWithPath: relativePath).lastPathComponent
            guard let extractedData = allExtracted[filename] else {
                XCTFail("file not found after round-trip: \(relativePath) (filename: \(filename))")
                continue
            }
            XCTAssertEqual(extractedData, originalData, "content mismatch for \(relativePath)")
        }
    }

    private func allFiles(under root: URL) -> [String: Data] {
        var result: [String: Data] = [:]
        guard let enumerator = FileManager.default
            .enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])
        else {
            return result
        }
        for case let fileURL as URL in enumerator {
            let rv = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard rv?.isRegularFile == true else { continue }
            if let data = try? Data(contentsOf: fileURL) {
                result[fileURL.lastPathComponent] = data
            }
        }
        return result
    }

    func testCompressionNoneProducesLargerArchive() async throws {
        let srcRoot = self.tmp.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: srcRoot, withIntermediateDirectories: true)
        // Highly compressible content.
        try Data(repeating: 0, count: 8192).write(to: srcRoot.appendingPathComponent("zeros.bin"))

        let compressedURL = self.tmp.appendingPathComponent("compressed.zip")
        let uncompressedURL = self.tmp.appendingPathComponent("uncompressed.zip")

        let compressor = ArchiveCreator(compressionLevel: .best)
        let deflated = try await compressor.createZip(sources: [srcRoot], relativeTo: self.tmp, archive: compressedURL)

        let none = ArchiveCreator(compressionLevel: .none)
        let stored = try await none.createZip(sources: [srcRoot], relativeTo: self.tmp, archive: uncompressedURL)

        XCTAssertLessThan(deflated, stored, "deflated archive should be smaller than stored for compressible data")
    }

    func testCompressionNoneAndBestProduceSameExtractedContent() async throws {
        let srcRoot = self.tmp.appendingPathComponent("src2", isDirectory: true)
        try FileManager.default.createDirectory(at: srcRoot, withIntermediateDirectories: true)
        _ = try Fixtures.seedDirectory(at: srcRoot)

        for level in [CompressionLevel.none, .best] {
            let archiveURL = self.tmp.appendingPathComponent("level-\(level).zip")
            let creator = ArchiveCreator(compressionLevel: level)
            try await creator.createZip(sources: [srcRoot], relativeTo: self.tmp, archive: archiveURL)

            let destURL = self.tmp.appendingPathComponent("extracted-\(level)", isDirectory: true)
            try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
            let extractor = ArchiveExtractor()
            _ = try await extractor.extract(archive: archiveURL, to: destURL)
            // If extraction succeeds without error, the contents are valid.
        }
    }
}
