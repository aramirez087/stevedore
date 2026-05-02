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

    func testExecute_trashesAssociatedFiles_sourceMissing() async throws {
        let fileURL = try self.makeTempFile(name: "com.test.SomeApp Preferences")
        let bundleURL = try makeTestBundle(in: self.tmpDir)
        let metadata = try AppMetadataReader().readMetadata(from: bundleURL)
        let file = AssociatedFile(
            url: fileURL,
            sizeInBytes: 0,
            lastModified: Date(),
            confidence: .high,
            reason: "Test",
            requiresAdmin: false
        )
        let plan = UninstallPlan(appMetadata: metadata, selectedFiles: [file])
        let executor = UninstallExecutor()
        try await executor.execute(plan: plan)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path(percentEncoded: false)))
    }

    func testExecute_skipsRequiresAdminFiles() async throws {
        let adminFileURL = self.tmpDir.appending(path: "admin_file", directoryHint: .notDirectory)
        let bundleURL = try makeTestBundle(in: self.tmpDir)
        let metadata = try AppMetadataReader().readMetadata(from: bundleURL)
        let adminFile = AssociatedFile(
            url: adminFileURL,
            sizeInBytes: 0,
            lastModified: Date(),
            confidence: .high,
            reason: "Test",
            requiresAdmin: true
        )
        let plan = UninstallPlan(appMetadata: metadata, selectedFiles: [adminFile])
        let executor = UninstallExecutor()
        try await executor.execute(plan: plan)
        // adminFile was never created, but no error expected since requiresAdmin files are skipped
        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path(percentEncoded: false)))
    }

    func testExecute_throwsTrashFailed_onError() async throws {
        let nonexistentURL = self.tmpDir.appending(path: "DoesNotExist.app", directoryHint: .isDirectory)
        let metadata = AppMetadata(
            bundleURL: nonexistentURL,
            bundleID: "com.test.Gone",
            bundleName: "Gone",
            executableName: "Gone",
            version: nil,
            bundleSizeInBytes: 0
        )
        let plan = UninstallPlan(appMetadata: metadata, selectedFiles: [])
        let executor = UninstallExecutor()
        do {
            try await executor.execute(plan: plan)
            XCTFail("Expected error")
        } catch UninstallerError.trashFailed(let url, _) {
            XCTAssertEqual(url, nonexistentURL)
        }
    }

    func testNoRemoveItemCall() throws {
        let worktree = "/Users/aramirez/Code/.epic-worktrees/Stevedore/epic-stevedore-mvp--s25-uninstaller-ui"
        let sourcePath = "\(worktree)/Sources/Features/Uninstaller/UninstallExecutor.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        XCTAssertFalse(source.contains("removeItem"), "UninstallExecutor must not call removeItem")
    }
}
