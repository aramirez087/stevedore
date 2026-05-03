import FeaturesUninstaller
import Foundation
import UIUninstallerUI
import XCTest

@MainActor
final class UninstallerViewModelTests: XCTestCase {
    private var tmpDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        self.tmpDir = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: self.tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmpDir)
        try await super.tearDown()
    }

    private func makeBundle(bundleID: String = "com.test.App") throws -> URL {
        let bundleURL = self.tmpDir.appending(path: "TestApp.app", directoryHint: .isDirectory)
        let contents = bundleURL.appending(path: "Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleExecutable": "TestApp",
            "CFBundleName": "TestApp",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appending(path: "Info.plist", directoryHint: .notDirectory))
        return bundleURL
    }

    // MARK: - Drop handling

    func testLoad_nonAppExtension_setsDropError() async {
        let vm = UninstallerViewModel()
        await vm.load(appURL: URL(filePath: "/tmp/SomeFolder"))
        XCTAssertNotNil(vm.dropError)
        XCTAssertEqual(vm.scanState, .idle)
    }

    func testLoad_missingInfoPlist_setsDropError() async throws {
        let vm = UninstallerViewModel()
        let emptyApp = self.tmpDir.appending(path: "Empty.app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: emptyApp, withIntermediateDirectories: true)
        await vm.load(appURL: emptyApp)
        XCTAssertNotNil(vm.dropError)
        XCTAssertEqual(vm.scanState, .idle)
    }

    func testLoad_validBundle_transitionsToReady() async throws {
        let vm = UninstallerViewModel()
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        XCTAssertEqual(vm.scanState, .ready)
        XCTAssertNil(vm.dropError)
    }

    func testDropError_clearedOnSubsequentSuccessfulLoad() async throws {
        let vm = UninstallerViewModel()
        // First load a bad path
        await vm.load(appURL: URL(filePath: "/tmp/NoExtension"))
        XCTAssertNotNil(vm.dropError)
        // Then load a valid bundle
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        XCTAssertNil(vm.dropError)
    }

    // MARK: - Row selection (direct manipulation)

    func testRowToggle_checksAndUnchecks() {
        let vm = UninstallerViewModel()
        let row = FileRow(file: makeMediumConfidenceFile(), selected: false)
        vm.rows = [row]
        XCTAssertFalse(vm.rows[0].isSelected)
        vm.rows[0].isSelected = true
        XCTAssertTrue(vm.rows[0].isSelected)
        vm.rows[0].isSelected = false
        XCTAssertFalse(vm.rows[0].isSelected)
    }

    // MARK: - Confirmation count

    func testConfirmationCount_reflectsSelectedRowsPlusBundleAlways() {
        let vm = UninstallerViewModel()
        vm.metadata = .fake()
        vm.rows = [
            FileRow(file: makeHighConfidenceFile(), selected: true),
            FileRow(file: makeMediumConfidenceFile(), selected: true),
            FileRow(file: makeLowConfidenceFile(), selected: false),
        ]
        // app bundle (1) + 2 selected = 3
        XCTAssertEqual(vm.confirmationItemCount, 3)

        vm.rows[1].isSelected = false
        // app bundle (1) + 1 selected = 2
        XCTAssertEqual(vm.confirmationItemCount, 2)
    }

    // MARK: - canConfirm

    func testCanConfirm_requiresReadyStateAndMetadata() {
        let vm = UninstallerViewModel()
        XCTAssertFalse(vm.canConfirm)
        vm.metadata = .fake()
        vm.scanState = .ready
        XCTAssertTrue(vm.canConfirm)
    }

    // MARK: - confirm() integration

    func testConfirm_trashesFiles_invokesCallbacks() async throws {
        let bundleURL = try self.makeBundle()
        let fileURL = self.tmpDir.appending(path: "com.test.App Support", directoryHint: .notDirectory)
        try "data".write(to: fileURL, atomically: true, encoding: .utf8)
        let scanner = AssociatedFilesScanner(
            searchPaths: [SearchPath(url: self.tmpDir, kind: .user)]
        )
        let vm = UninstallerViewModel(scanner: scanner)
        await vm.load(appURL: bundleURL)
        XCTAssertEqual(vm.scanState, .ready)

        var capturedSummary: UninstallSummary?
        var dismissCalled = false
        vm.onCompleted = { capturedSummary = $0 }
        vm.onDismiss = { dismissCalled = true }

        await vm.confirm()

        XCTAssertTrue(dismissCalled, "onDismiss should be called after confirm")
        XCTAssertNotNil(capturedSummary, "onCompleted should be called with a summary")
        // Bundle itself must be gone
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: bundleURL.path(percentEncoded: false)),
            "App bundle should have been moved to Trash"
        )
    }
}
