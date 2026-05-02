import Core
import FeaturesUninstaller
import UIUninstallerUI
import XCTest

/// Verifies drop and load behaviour: valid bundles scan, invalid paths show errors.
@MainActor
final class UninstallerUIDropHandlingTests: XCTestCase {
    // MARK: - Valid bundle

    func testLoadValidBundleTransitionsToReady() async throws {
        let bundleURL = try makeTemporaryAppBundle(bundleID: "com.test.ValidApp", displayName: "ValidApp")
        defer { try? FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent()) }

        let vm = UninstallerViewModel()
        await vm.load(appURL: bundleURL)

        XCTAssertEqual(vm.scanState, .ready)
        XCTAssertNotNil(vm.metadata)
        XCTAssertEqual(vm.metadata?.bundleID, "com.test.ValidApp")
        XCTAssertNil(vm.dropError)
    }

    // MARK: - Non-.app path

    func testLoadNonAppPathSetsDropErrorAndStaysIdle() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = UninstallerViewModel()
        await vm.load(appURL: tempDir)

        XCTAssertEqual(vm.scanState, .idle,
                       "Non-.app path must leave scan state idle, not enter the scan flow")
        XCTAssertNotNil(vm.dropError,
                        "Non-.app path must set dropError")
        XCTAssertNil(vm.metadata,
                     "No metadata should be populated for an invalid path")
    }

    func testLoadPathWithAppExtensionButMissingInfoPlistSetsError() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).app")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // No Contents/Info.plist → should fail

        let vm = UninstallerViewModel()
        await vm.load(appURL: tmp)

        XCTAssertEqual(vm.scanState, .idle)
        XCTAssertNotNil(vm.dropError)
    }

    func testDropErrorClearedOnSubsequentSuccessfulLoad() async throws {
        // First, load a bad path
        let notApp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: notApp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: notApp) }

        let vm = UninstallerViewModel()
        await vm.load(appURL: notApp)
        XCTAssertNotNil(vm.dropError)

        // Now load a valid bundle
        let bundleURL = try makeTemporaryAppBundle(bundleID: "com.test.Good", displayName: "GoodApp")
        defer { try? FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent()) }

        await vm.load(appURL: bundleURL)
        XCTAssertNil(vm.dropError, "dropError must be cleared on a successful subsequent load")
        XCTAssertEqual(vm.scanState, .ready)
    }

    // MARK: - AppMetadataReader unit tests

    func testReaderRejectsNonDotAppExtension() {
        let reader = AppMetadataReader()
        let url = URL(filePath: "/Applications/NotAnApp")
        XCTAssertThrowsError(try reader.read(from: url)) { error in
            guard case AppMetadataReaderError.notAnAppBundle = error else {
                XCTFail("Expected notAnAppBundle error, got \(error)")
                return
            }
        }
    }

    func testReaderRejectsMissingInfoPlist() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).app")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let reader = AppMetadataReader()
        XCTAssertThrowsError(try reader.read(from: tmp)) { error in
            guard case AppMetadataReaderError.missingInfoPlist = error else {
                XCTFail("Expected missingInfoPlist error, got \(error)")
                return
            }
        }
    }

    func testReaderParsesValidBundle() throws {
        let bundleURL = try makeTemporaryAppBundle(bundleID: "com.test.MyApp", displayName: "My App")
        defer { try? FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent()) }

        let reader = AppMetadataReader()
        let meta = try reader.read(from: bundleURL)

        XCTAssertEqual(meta.bundleID, "com.test.MyApp")
        XCTAssertEqual(meta.displayName, "My App")
        XCTAssertEqual(meta.executableName, "MyApp")
    }

    // MARK: - Helpers

    /// Creates a minimal .app bundle in a temp directory and returns its URL.
    private func makeTemporaryAppBundle(
        bundleID: String,
        displayName: String,
        executable: String = "MyApp"
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let contents = root.appendingPathComponent("\(displayName).app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let plist: NSDictionary = [
            "CFBundleIdentifier": bundleID,
            "CFBundleDisplayName": displayName,
            "CFBundleExecutable": executable,
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "100",
        ]
        let plistURL = contents.appendingPathComponent("Info.plist")
        try plist.write(to: plistURL)

        return contents.deletingLastPathComponent()
    }
}
