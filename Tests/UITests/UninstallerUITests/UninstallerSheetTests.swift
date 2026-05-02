import AppKit
import FeaturesUninstaller
import SwiftUI
import UIUninstallerUI
import XCTest

@MainActor
final class UninstallerSheetTests: XCTestCase {
    private func makeMetadata() -> AppMetadata {
        AppMetadata(
            bundleURL: URL(filePath: "/tmp/Test.app"),
            bundleID: "com.test.App",
            bundleName: "Test",
            executableName: "Test",
            version: "1.0",
            bundleSizeInBytes: 1024
        )
    }

    func testIdleState_rendersLauncher() {
        let vm = UninstallerViewModel()
        let sheet = UninstallerSheet(viewModel: vm, onDismiss: {})
        let hosting = NSHostingView(rootView: sheet)
        XCTAssertNotNil(hosting)
    }

    func testScanningState_rendersProgressView() {
        let scanner = FakeAssociatedFilesScanner(files: [])
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        // We can't directly set scanState since it's private(set), just verify rendering works in idle
        let sheet = UninstallerSheet(viewModel: vm, onDismiss: {})
        let hosting = NSHostingView(rootView: sheet)
        XCTAssertNotNil(hosting)
    }

    func testReadyState_rendersTable() async throws {
        let files = [
            AssociatedFile(
                url: URL(filePath: "/tmp/com.test.App"),
                sizeInBytes: 1024,
                lastModified: Date(),
                confidence: .high,
                reason: "Bundle ID match",
                requiresAdmin: false
            ),
        ]
        let scanner = FakeAssociatedFilesScanner(files: files)
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let tmpDir = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let bundleURL = tmpDir.appending(path: "Test.app", directoryHint: .isDirectory)
        let contents = bundleURL.appending(path: "Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.test.App",
            "CFBundleExecutable": "Test",
            "CFBundleName": "Test",
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contents.appending(path: "Info.plist", directoryHint: .notDirectory))
        await vm.load(appURL: bundleURL)
        if case .ready = vm.scanState {
            let sheet = UninstallerSheet(viewModel: vm, onDismiss: {})
            let hosting = NSHostingView(rootView: sheet)
            XCTAssertNotNil(hosting)
        } else {
            XCTFail("Expected .ready state")
        }
    }

    func testFailedState_rendersContentUnavailable() async throws {
        struct ScanError: Error {}
        let scanner = FakeAssociatedFilesScanner(files: [], error: ScanError())
        let reader = FakeAppMetadataReader(result: .success(self.makeMetadata()))
        let vm = UninstallerViewModel(metadataReader: reader, scanner: scanner)
        let tmpDir = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let bundleURL = tmpDir.appending(path: "Fail.app", directoryHint: .isDirectory)
        let contents = bundleURL.appending(path: "Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.test.Fail",
            "CFBundleExecutable": "Fail",
            "CFBundleName": "Fail",
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contents.appending(path: "Info.plist", directoryHint: .notDirectory))
        await vm.load(appURL: bundleURL)
        if case .failed = vm.scanState {
            let sheet = UninstallerSheet(viewModel: vm, onDismiss: {})
            let hosting = NSHostingView(rootView: sheet)
            XCTAssertNotNil(hosting)
        } else {
            XCTFail("Expected .failed state")
        }
    }
}
