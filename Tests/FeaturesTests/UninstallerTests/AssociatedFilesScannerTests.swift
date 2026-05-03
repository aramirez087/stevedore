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
        AssociatedFilesScanner(searchPaths: [
            SearchPath(url: self.userDir, kind: .user),
            SearchPath(url: self.systemDir, kind: .system),
        ])
    }

    private func makeFile(in dir: URL, name: String) throws -> URL {
        let url = dir.appending(path: name, directoryHint: .notDirectory)
        try "test".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testScan_findsMatchingTopLevelItem() throws {
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.mygreatapp")
        _ = try self.makeFile(in: self.userDir, name: "mygreatapp")
        let results = self.makeScanner().scan(for: metadata)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.url.lastPathComponent == "mygreatapp" })
    }

    func testScan_excludesNonMatchingItems() throws {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.example.uniqueappzzz",
            bundleName: "UniqueAppZZZ",
            executableName: "UniqueAppZZZ"
        )
        _ = try self.makeFile(in: self.userDir, name: "SomeOtherThing.plist")
        let results = self.makeScanner().scan(for: metadata)
        XCTAssertTrue(results.isEmpty)
    }

    func testScan_systemPathFiles_flaggedRequiresAdmin() throws {
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.adminapp")
        _ = try self.makeFile(in: self.systemDir, name: "adminapp")
        let results = self.makeScanner().scan(for: metadata)
        let systemFiles = results.filter(\.requiresAdmin)
        XCTAssertFalse(systemFiles.isEmpty)
    }

    func testScan_emptyDirectory_returnsEmpty() {
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.nothing")
        let results = self.makeScanner().scan(for: metadata)
        XCTAssertTrue(results.isEmpty)
    }

    func testScan_sortedByScoreDescending() throws {
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.sortapp", bundleName: "SortApp")
        // High-signal file: full bundle ID in name
        _ = try self.makeFile(in: self.userDir, name: "com.example.sortapp")
        // Medium-signal file: app name only
        _ = try self.makeFile(in: self.userDir, name: "sortapp Support")
        let results = self.makeScanner().scan(for: metadata)
        XCTAssertGreaterThanOrEqual(results.count, 2)
        for i in 1 ..< results.count {
            XCTAssertGreaterThanOrEqual(results[i - 1].scoreResult.score, results[i].scoreResult.score)
        }
    }

    func testScan_nonexistentSearchPath_isSkippedGracefully() {
        let missing = self.tmpDir.appending(path: "does_not_exist", directoryHint: .isDirectory)
        let scanner = AssociatedFilesScanner(searchPaths: [SearchPath(url: missing, kind: .user)])
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.anything")
        XCTAssertNoThrow(scanner.scan(for: metadata))
        XCTAssertTrue(scanner.scan(for: metadata).isEmpty)
    }

    func testScan_belowMinimumScore_excluded() throws {
        // Create a scanner with a very high minimum so even moderate matches are excluded
        let strictScanner = AssociatedFilesScanner(
            minimumScore: 0.99,
            searchPaths: [SearchPath(url: self.userDir, kind: .user)]
        )
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.strictapp")
        // Only partial name match — will score below 0.99
        _ = try self.makeFile(in: self.userDir, name: "strictapp Preferences")
        let results = strictScanner.scan(for: metadata)
        XCTAssertTrue(results.isEmpty)
    }
}
