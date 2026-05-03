@testable import FeaturesUninstaller
import Foundation
import XCTest

final class MatchScorerTests: XCTestCase {
    private var tmpDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        self.tmpDir = try makeTempDirectory()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.tmpDir)
        try await super.tearDown()
    }

    private func url(_ name: String) -> URL {
        self.tmpDir.appending(path: name, directoryHint: .notDirectory)
    }

    func testExactBundleIDComponent_returnsHighConfidence() {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.example.myawesomeapp"
        )
        let itemURL = self.url("myawesomeapp")
        let (score, reason) = MatchScorer.score(url: itemURL, metadata: metadata)
        XCTAssertGreaterThanOrEqual(score, 0.7)
        XCTAssertEqual(reason, "Bundle ID match")
    }

    func testBundleNameSubstring_returnsMediumOrHighConfidence() {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.example.X",
            bundleName: "SuperEditor"
        )
        let itemURL = self.url("supereditor Support")
        let (score, _) = MatchScorer.score(url: itemURL, metadata: metadata)
        XCTAssertGreaterThanOrEqual(score, 0.4)
    }

    func testExecutableNameMatch_returnsMediumConfidence() {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.x.X",
            bundleName: "XApp",
            executableName: "superexec"
        )
        let itemURL = self.url("superexec Preferences")
        let (score, reason) = MatchScorer.score(url: itemURL, metadata: metadata)
        XCTAssertGreaterThanOrEqual(score, 0.4)
        XCTAssertEqual(reason, "Executable name match")
    }

    func testShortBundleIDComponent_belowFourChars_doesNotScoreHigh() {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.ex.app",
            bundleName: "ZZZUnique"
        )
        let itemURL = self.url("app Support Folder")
        let (score, _) = MatchScorer.score(url: itemURL, metadata: metadata)
        XCTAssertLessThan(score, 0.9)
    }

    func testConfidence_mappedCorrectly_from_score() {
        XCTAssertEqual(Confidence.from(score: 0.9), .high)
        XCTAssertEqual(Confidence.from(score: 0.7), .high)
        XCTAssertEqual(Confidence.from(score: 0.5), .medium)
        XCTAssertEqual(Confidence.from(score: 0.4), .medium)
        XCTAssertEqual(Confidence.from(score: 0.1), .low)
        XCTAssertEqual(Confidence.from(score: 0.0), .low)
    }
}
