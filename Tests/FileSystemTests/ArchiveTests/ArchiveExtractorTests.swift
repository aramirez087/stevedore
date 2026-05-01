import Core
@testable import FileSystemArchive
import Foundation
import XCTest

final class ArchiveExtractorTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        self.tmp = try makeTempDir(label: "ExtractorTests")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmp)
    }

    func testExtractWithProgressCallbacks() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let targetURL = self.tmp.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)

        let reporter = RecordingProgressReporter()
        let extractor = ArchiveExtractor(progress: reporter, conflictPolicy: .overwrite)
        let result = try await extractor.extract(archive: archiveURL, to: targetURL)

        XCTAssertGreaterThan(result.entriesExtracted, 0)

        let reports = await reporter.reports
        XCTAssertFalse(reports.isEmpty, "expected progress reports")

        // Last report should be completed.
        XCTAssertEqual(reports.last?.phase, Core.Progress.Phase.completed)

        // Bytes done should be monotonically non-decreasing.
        let transferring = reports.filter { $0.phase == Core.Progress.Phase.transferring }
        var prev: Int64 = 0
        for r in transferring {
            XCTAssertGreaterThanOrEqual(r.bytesDone, prev)
            prev = r.bytesDone
        }
    }

    func testSkipConflictPolicy() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let targetURL = self.tmp.appendingPathComponent("out-skip", isDirectory: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)

        // Pre-seed a file with different content.
        let preSeedURL = targetURL.appendingPathComponent("a.txt")
        let originalContent = Data("original content".utf8)
        try originalContent.write(to: preSeedURL)

        let extractor = ArchiveExtractor(conflictPolicy: .skip)
        _ = try await extractor.extract(archive: archiveURL, to: targetURL)

        // Existing file must not have been overwritten.
        let content = try Data(contentsOf: preSeedURL)
        XCTAssertEqual(content, originalContent, "skip policy must preserve existing file")
    }

    func testCancellationLeavesNoStagingArtifacts() async throws {
        // Build a zip with enough entries to take > 50 ms.
        let archiveURL = try await self.buildLargeZip()
        let targetURL = self.tmp.appendingPathComponent("out-cancel", isDirectory: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)

        let extractor = ArchiveExtractor(conflictPolicy: .overwrite)
        let task = Task {
            try await extractor.extract(archive: archiveURL, to: targetURL)
        }

        // Give the extractor time to begin staging.
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            // If we get here the archive was too small and extraction finished before cancel.
            // That's not a test failure — staging is still cleaned up.
        } catch StevedoreError.cancelled {
            // expected
        } catch is CancellationError {
            // also acceptable
        }

        // No staging artifact should remain.
        let kids = (try? FileManager.default.contentsOfDirectory(atPath: targetURL.path)) ?? []
        let stagingArtifacts = kids.filter { $0.hasPrefix(".stevedore-extract-") }
        XCTAssertTrue(stagingArtifacts.isEmpty, "staging artifacts remain: \(stagingArtifacts)")
    }

    // MARK: - Private

    private func buildLargeZip() async throws -> URL {
        let srcRoot = self.tmp.appendingPathComponent("large-src", isDirectory: true)
        try FileManager.default.createDirectory(at: srcRoot, withIntermediateDirectories: true)
        // 60 files of 1 KB each = 60 KB, enough to take meaningful time.
        for i in 0 ..< 60 {
            let fileURL = srcRoot.appendingPathComponent("file-\(i).bin")
            try Data(repeating: UInt8(i & 0xFF), count: 1024).write(to: fileURL)
        }
        let archiveURL = self.tmp.appendingPathComponent("large.zip")
        let creator = ArchiveCreator()
        try await creator.createZip(sources: [srcRoot], relativeTo: self.tmp, archive: archiveURL)
        return archiveURL
    }
}
