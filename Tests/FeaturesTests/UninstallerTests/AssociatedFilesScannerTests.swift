import FeaturesUninstaller
import Foundation
import XCTest

final class AssociatedFilesScannerTests: XCTestCase {
    private var tmpDir: URL!
    private var userDir: URL!
    private var systemDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        self.tmpDir = try makeTempDirectory()
        self.userDir = self.tmpDir.appending(path: "user", directoryHint: .isDirectory)
        self.systemDir = self.tmpDir.appending(path: "system", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: self.userDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: self.systemDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmpDir)
        try await super.tearDown()
    }

    private func makeScanner() -> AssociatedFilesScanner {
        AssociatedFilesScanner(
            userSearchPaths: [self.userDir],
            systemSearchPaths: [self.systemDir]
        )
    }

    private func makeFile(in dir: URL, name: String) throws -> URL {
        let url = dir.appending(path: name, directoryHint: .notDirectory)
        try "test".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testScan_findsMatchingTopLevelItem() async throws {
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.mygreatapp")
        _ = try self.makeFile(in: self.userDir, name: "mygreatapp")
        let scanner = self.makeScanner()
        let results = try await scanner.scan(for: metadata)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.url.lastPathComponent == "mygreatapp" })
    }

    func testScan_excludesNonMatchingItems() async throws {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.example.uniqueappzzz",
            bundleName: "UniqueAppZZZ",
            executableName: "UniqueAppZZZ"
        )
        _ = try self.makeFile(in: self.userDir, name: "SomeOtherThing.plist")
        let scanner = self.makeScanner()
        let results = try await scanner.scan(for: metadata)
        XCTAssertTrue(results.isEmpty)
    }

    func testScan_systemPathFiles_flaggedRequiresAdmin() async throws {
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.adminapp")
        _ = try self.makeFile(in: self.systemDir, name: "adminapp")
        let scanner = self.makeScanner()
        let results = try await scanner.scan(for: metadata)
        let systemFiles = results.filter(\.requiresAdmin)
        XCTAssertFalse(systemFiles.isEmpty)
    }

    func testScan_emptyDirectory_returnsEmpty() async throws {
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.nothing")
        let scanner = self.makeScanner()
        let results = try await scanner.scan(for: metadata)
        XCTAssertTrue(results.isEmpty)
    }
}
