import FeaturesUninstaller
import Foundation
import XCTest

final class AppMetadataReaderTests: XCTestCase {
    private var tmpDir: URL!
    private let reader = AppMetadataReader()

    override func setUp() async throws {
        try await super.setUp()
        self.tmpDir = try makeTempDirectory()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmpDir)
        try await super.tearDown()
    }

    func testValidBundle_returnsMetadata() throws {
        let bundleURL = try makeTestBundle(in: self.tmpDir)
        let metadata = try self.reader.read(from: bundleURL)
        XCTAssertEqual(metadata.bundleID, "com.example.TestApp")
        XCTAssertEqual(metadata.displayName, "TestApp")
        XCTAssertEqual(metadata.executableName, "TestApp")
        XCTAssertEqual(metadata.version, "1.0")
    }

    func testMissingPlist_throwsMissingInfoPlist() throws {
        let bundleURL = self.tmpDir.appending(path: "Empty.app", directoryHint: .isDirectory)
        let contentsURL = bundleURL.appending(path: "Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        XCTAssertThrowsError(try self.reader.read(from: bundleURL)) { error in
            if case AppMetadataReaderError.missingInfoPlist = error { } else {
                XCTFail("Expected missingInfoPlist, got \(error)")
            }
        }
    }

    func testMissingBundleID_throwsMissingRequiredKey() throws {
        let bundleURL = self.tmpDir.appending(path: "Bad.app", directoryHint: .isDirectory)
        let contentsURL = bundleURL.appending(path: "Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleExecutable": "Bad"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contentsURL.appending(path: "Info.plist", directoryHint: .notDirectory))
        XCTAssertThrowsError(try self.reader.read(from: bundleURL)) { error in
            if case AppMetadataReaderError.missingRequiredKey = error { } else {
                XCTFail("Expected missingRequiredKey, got \(error)")
            }
        }
    }

    func testVersionIsOptional_returnsNilWhenAbsent() throws {
        let bundleURL = try makeTestBundle(in: self.tmpDir, version: nil)
        let metadata = try self.reader.read(from: bundleURL)
        XCTAssertNil(metadata.version)
        XCTAssertNil(metadata.shortVersion)
    }
}
