import FeaturesUninstaller
import Foundation
import XCTest

final class UninstallExecutorTests: XCTestCase {
    private var tmpDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        self.tmpDir = try makeTempDirectory()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmpDir)
        try await super.tearDown()
    }

    private func makeTempFile(name: String) throws -> URL {
        let url = self.tmpDir.appending(path: name, directoryHint: .notDirectory)
        try "test".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testExecute_trashesAppBundleAndAssociatedFiles() throws {
        let fileURL = try self.makeTempFile(name: "com.test.SomeApp Preferences")
        let bundleURL = try makeTestBundle(in: self.tmpDir)
        let metadata = try AppMetadataReader().read(from: bundleURL)
        let file = makeAssociatedFile(url: fileURL)
        let plan = UninstallPlan(metadata: metadata, selectedFiles: [file])
        let summary = UninstallExecutor().execute(plan)
        XCTAssertTrue(summary.allSucceeded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path(percentEncoded: false)))
    }

    func testExecute_missingBundle_recordsFailure() {
        let nonexistentURL = self.tmpDir.appending(path: "DoesNotExist.app", directoryHint: .isDirectory)
        let metadata = AppMetadata(
            bundleURL: nonexistentURL,
            bundleID: "com.test.Gone",
            displayName: "Gone",
            executableName: "Gone",
            version: nil,
            shortVersion: nil
        )
        let plan = UninstallPlan(metadata: metadata, selectedFiles: [])
        let summary = UninstallExecutor().execute(plan)
        XCTAssertFalse(summary.allSucceeded)
        XCTAssertEqual(summary.failed.first?.url, nonexistentURL)
    }

    func testExecute_partialSuccess_separatesSucceededAndFailed() throws {
        let existingURL = try self.makeTempFile(name: "existing_file")
        let missingURL = self.tmpDir.appending(path: "ghost.file", directoryHint: .notDirectory)
        let metadata = AppMetadata(
            bundleURL: existingURL,
            bundleID: "com.test.Partial",
            displayName: "Partial",
            executableName: "Partial",
            version: nil,
            shortVersion: nil
        )
        let missingFile = makeAssociatedFile(url: missingURL)
        let plan = UninstallPlan(metadata: metadata, selectedFiles: [missingFile])
        let summary = UninstallExecutor().execute(plan)
        // existingURL (bundle) succeeds, missingURL fails
        XCTAssertEqual(summary.succeeded.count, 1)
        XCTAssertEqual(summary.failed.count, 1)
        XCTAssertFalse(summary.allSucceeded)
        XCTAssertEqual(summary.failed.first?.url, missingURL)
    }

    func testExecute_emptyPlan_bundleOnlyTrashed() throws {
        let bundleURL = try makeTestBundle(in: self.tmpDir)
        let metadata = try AppMetadataReader().read(from: bundleURL)
        let plan = UninstallPlan(metadata: metadata, selectedFiles: [])
        let summary = UninstallExecutor().execute(plan)
        XCTAssertTrue(summary.allSucceeded)
        XCTAssertEqual(summary.itemResults.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path(percentEncoded: false)))
    }

    func testNoRemoveItemCall() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/Features/Uninstaller/UninstallExecutor.swift")
            .path
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        XCTAssertFalse(source.contains("removeItem"), "UninstallExecutor must not call removeItem")
    }
}
