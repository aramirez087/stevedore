import Core
@testable import FileSystemArchive
import Foundation
import XCTest

final class ArchiveProviderTests: XCTestCase {
    private var tmp: URL!

    override func setUp() async throws {
        self.tmp = try makeTempDir(label: "ProviderTests")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmp)
    }

    func testEnumerateRootYieldsEntries() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let provider = try await ArchiveProvider(archiveURL: archiveURL)
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: .root(.local), options: .default) {
            items.append(item)
        }
        XCTAssertFalse(items.isEmpty, "root enumeration must yield at least one item")
    }

    func testEnumerateRecursiveYieldsFullTree() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let provider = try await ArchiveProvider(archiveURL: archiveURL)
        let recursive = EnumerationOptions(includesHiddenFiles: false, isRecursive: true)
        var items: [FileItem] = []
        for try await item in provider.enumerate(at: .root(.local), options: recursive) {
            items.append(item)
        }
        // Fixture has a.txt, dir/b.txt, dir/c.bin — at least 3 file entries.
        XCTAssertGreaterThanOrEqual(items.count, 3)
    }

    func testAttributesReturnsDataForKnownEntry() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let provider = try await ArchiveProvider(archiveURL: archiveURL)

        // Find a known file entry from recursive listing.
        let recursive = EnumerationOptions(isRecursive: true)
        var found: FilePath?
        let stream = provider.enumerate(at: .root(.local), options: recursive)
        for try await item in stream where item.kind == .regularFile {
            found = item.path
            break
        }
        guard let foundPath = found else { XCTFail("no file entry found")
            return
        }
        let attrs = try await provider.attributes(at: foundPath)
        XCTAssertNotNil(attrs.sizeInBytes)
    }

    func testAttributesRootReturnsSyntheticDirectory() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let provider = try await ArchiveProvider(archiveURL: archiveURL)
        let attrs = try await provider.attributes(at: .root(.local))
        XCTAssertNotNil(attrs)
    }

    func testExecuteExtractOperation() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let provider = try await ArchiveProvider(archiveURL: archiveURL)
        let destURL = self.tmp.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)

        let op = OperationDescriptor(
            kind: .extract,
            sources: [.root(.local)],
            destination: FilePath(scheme: .local, posix: destURL.path)
        )
        let result = try await provider.execute(op, progress: nil)
        XCTAssertEqual(result.status, .completed)
        XCTAssertGreaterThan(result.itemsProcessed, 0)
    }

    func testNonExtractOperationThrowsUnsupported() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let provider = try await ArchiveProvider(archiveURL: archiveURL)
        let op = OperationDescriptor(
            kind: .copy,
            sources: [.root(.local)],
            destination: FilePath(scheme: .local, posix: "/tmp/dest")
        )
        do {
            _ = try await provider.execute(op, progress: nil)
            XCTFail("expected unsupported error")
        } catch StevedoreError.unsupported {
            // expected
        }
    }

    func testWatchProducesEmptyStream() async throws {
        let archiveURL = try await Fixtures.zipFixture(at: self.tmp)
        let provider = try await ArchiveProvider(archiveURL: archiveURL)
        var changes: [FilePathChange] = []
        for await change in provider.watch(.root(.local)) {
            changes.append(change)
        }
        XCTAssertTrue(changes.isEmpty, "watch stream must be empty for read-only archive provider")
    }

    func testInitThrowsForNonExistentFile() async {
        let fakeURL = self.tmp.appendingPathComponent("nonexistent.zip")
        do {
            _ = try await ArchiveProvider(archiveURL: fakeURL)
            XCTFail("expected error")
        } catch StevedoreError.fileSystem {
            // expected
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testInitThrowsForUnsupportedFormat() async throws {
        let textURL = self.tmp.appendingPathComponent("plain.txt")
        try Data("hello".utf8).write(to: textURL)
        do {
            _ = try await ArchiveProvider(archiveURL: textURL)
            XCTFail("expected unsupportedFormat error")
        } catch StevedoreError.archive(.unsupportedFormat) {
            // expected
        }
    }
}
