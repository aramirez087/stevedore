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

    private func makeMetadata(bundleURL: URL? = nil) -> AppMetadata {
        AppMetadata(
            bundleURL: bundleURL ?? URL(filePath: "/tmp/TestApp.app"),
            bundleID: "com.test.App",
            bundleName: "TestApp",
            executableName: "TestApp",
            version: "1.0",
            bundleSizeInBytes: 1024
        )
    }

    private func makeFile(confidence: Confidence, requiresAdmin: Bool = false) -> AssociatedFile {
        AssociatedFile(
            url: URL(filePath: "/tmp/\(UUID().uuidString)"),
            sizeInBytes: 512,
            lastModified: Date(),
            confidence: confidence,
            reason: "Test",
            requiresAdmin: requiresAdmin
        )
    }

    // MARK: - Default selection tests

    func testHighConfidence_selectedByDefault() async throws {
        let highFile = self.makeFile(confidence: .high)
        let scanner = FakeAssociatedFilesScanner(files: [highFile])
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        XCTAssertTrue(vm.selectedIDs.contains(highFile.id))
    }

    func testMediumConfidence_notSelectedByDefault() async throws {
        let medFile = self.makeFile(confidence: .medium)
        let scanner = FakeAssociatedFilesScanner(files: [medFile])
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        XCTAssertFalse(vm.selectedIDs.contains(medFile.id))
    }

    func testAdminPath_notInDefaultSelections() async throws {
        let adminFile = self.makeFile(confidence: .high, requiresAdmin: true)
        let scanner = FakeAssociatedFilesScanner(files: [adminFile])
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        XCTAssertFalse(vm.selectedIDs.contains(adminFile.id))
    }

    // MARK: - System path lock tests

    func testAdminPath_cannotBeToggled() async throws {
        let adminFile = self.makeFile(confidence: .high, requiresAdmin: true)
        let scanner = FakeAssociatedFilesScanner(files: [adminFile])
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        vm.toggleSelection(adminFile.id)
        XCTAssertFalse(vm.selectedIDs.contains(adminFile.id))
    }

    // MARK: - Confirmation text

    func testConfirmationText_updatesWithSelection() async throws {
        let file = self.makeFile(confidence: .high)
        let scanner = FakeAssociatedFilesScanner(files: [file])
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        XCTAssertTrue(vm.selectedIDs.contains(file.id))
        let textWithFile = vm.confirmationText
        vm.toggleSelection(file.id)
        let textWithoutFile = vm.confirmationText
        XCTAssertNotEqual(textWithFile, textWithoutFile)
        XCTAssertTrue(textWithFile.contains("2 items"))
        XCTAssertTrue(textWithoutFile.contains("1 item"))
    }

    // MARK: - Drop handling

    func testLoad_nonAppExtension_setsDropError() async {
        let vm = UninstallerViewModel()
        let url = URL(filePath: "/tmp/SomeFolder")
        await vm.load(appURL: url)
        XCTAssertNotNil(vm.dropError)
        if case .idle = vm.scanState { } else {
            XCTFail("scanState should remain idle on invalid drop")
        }
    }

    func testLoad_missingInfoPlist_setsDropError() async throws {
        let vm = UninstallerViewModel()
        let emptyApp = self.tmpDir.appending(path: "Empty.app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: emptyApp, withIntermediateDirectories: true)
        await vm.load(appURL: emptyApp)
        XCTAssertNotNil(vm.dropError)
        if case .idle = vm.scanState { } else {
            XCTFail("scanState should remain idle when Info.plist is missing")
        }
    }

    func testLoad_validBundle_entersScanning() async throws {
        let scanner = FakeAssociatedFilesScanner(files: [])
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        if case .ready = vm.scanState { } else {
            XCTFail("Expected .ready after successful load, got \(vm.scanState)")
        }
    }

    // MARK: - Sort

    func testSortBySize_respectsDirection() async throws {
        let small = AssociatedFile(
            url: URL(filePath: "/tmp/small"),
            sizeInBytes: 100,
            lastModified: Date(),
            confidence: .medium,
            reason: "Test",
            requiresAdmin: false
        )
        let large = AssociatedFile(
            url: URL(filePath: "/tmp/large"),
            sizeInBytes: 9000,
            lastModified: Date(),
            confidence: .medium,
            reason: "Test",
            requiresAdmin: false
        )
        let scanner = FakeAssociatedFilesScanner(files: [small, large])
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        vm.sortKey = .size
        vm.sortAscending = true
        let asc = vm.displayedFiles
        XCTAssertEqual(asc.first?.sizeInBytes, 100)
        vm.sortAscending = false
        let desc = vm.displayedFiles
        XCTAssertEqual(desc.first?.sizeInBytes, 9000)
    }

    // MARK: - Toggle

    func testToggleSelection_checksAndUnchecks() async throws {
        let file = self.makeFile(confidence: .medium)
        let scanner = FakeAssociatedFilesScanner(files: [file])
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let bundleURL = try self.makeBundle()
        await vm.load(appURL: bundleURL)
        XCTAssertFalse(vm.selectedIDs.contains(file.id))
        vm.toggleSelection(file.id)
        XCTAssertTrue(vm.selectedIDs.contains(file.id))
        vm.toggleSelection(file.id)
        XCTAssertFalse(vm.selectedIDs.contains(file.id))
    }
}
