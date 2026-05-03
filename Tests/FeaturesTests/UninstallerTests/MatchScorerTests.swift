@testable import FeaturesUninstaller
import Foundation
import XCTest

final class MatchScorerTests: XCTestCase {
    private var tmpDir: URL!
    private let scorer = MatchScorer()

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

    func testFullBundleIDInFilename_returnsHighConfidence() {
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.myawesomeapp")
        let result = self.scorer.score(self.url("com.example.myawesomeapp"), against: metadata)
        XCTAssertGreaterThanOrEqual(result.score, MatchScorer.highCutoff)
        XCTAssertTrue(result.reasons.contains { $0.contains("Bundle ID match") })
    }

    func testBundleNameSubstring_returnsMediumOrHighConfidence() {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.example.X",
            bundleName: "SuperEditor"
        )
        let result = self.scorer.score(self.url("supereditor Support"), against: metadata)
        XCTAssertGreaterThanOrEqual(result.score, MatchScorer.mediumCutoff)
    }

    func testExecutableNameMatch_contributesToScore() {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.x.X",
            bundleName: "XApp",
            executableName: "superexec"
        )
        let result = self.scorer.score(self.url("superexec Preferences"), against: metadata)
        XCTAssertGreaterThan(result.score, 0)
        XCTAssertTrue(result.reasons.contains { $0.contains("Executable") })
    }

    func testShortBundleIDComponent_belowFourChars_doesNotScoreHigh() {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.ex.app",
            bundleName: "ZZZUnique"
        )
        let result = self.scorer.score(self.url("app Support Folder"), against: metadata)
        XCTAssertLessThan(result.score, MatchScorer.highCutoff)
    }

    func testConfidenceLevel_mappedCorrectly() {
        func level(_ score: Double) -> ConfidenceLevel {
            ScoreResult(score: score, reasons: []).confidenceLevel
        }
        XCTAssertEqual(level(0.9), .high)
        XCTAssertEqual(level(MatchScorer.highCutoff), .high)
        XCTAssertEqual(level(0.4), .medium)
        XCTAssertEqual(level(MatchScorer.mediumCutoff), .medium)
        XCTAssertEqual(level(0.1), .low)
        XCTAssertEqual(level(0.0), .low)
    }

    func testNoMatch_returnsZeroScoreAndEmptyReasons() {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.example.uniqueapp",
            bundleName: "UniqueApp",
            executableName: "UniqueApp"
        )
        let result = self.scorer.score(self.url("completely_unrelated_xyz"), against: metadata)
        XCTAssertEqual(result.score, 0.0)
        XCTAssertTrue(result.reasons.isEmpty)
    }

    func testScore_cappedAtOne_whenMultipleSignalsMatch() {
        // Bundle ID in filename (0.70) + name match (0.25) + executable (0.15) > 1.0 → should cap
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.example.superapp",
            bundleName: "superapp",
            executableName: "superapp"
        )
        let result = self.scorer.score(self.url("com.example.superapp"), against: metadata)
        XCTAssertLessThanOrEqual(result.score, 1.0)
        XCTAssertGreaterThanOrEqual(result.score, MatchScorer.highCutoff)
    }

    func testCaseInsensitive_nameMatchesLowercasePath() {
        let metadata = makeAppMetadata(
            bundleURL: self.tmpDir,
            bundleID: "com.example.X",
            bundleName: "PhotoEditor",
            executableName: "PhotoEditor"
        )
        let result = self.scorer.score(self.url("photoeditor Preferences"), against: metadata)
        XCTAssertGreaterThanOrEqual(result.score, MatchScorer.mediumCutoff)
        XCTAssertTrue(result.reasons.contains { $0.contains("name") || $0.contains("Executable") })
    }

    func testBundleIDInPath_scoresLowerThanInFilename() {
        let metadata = makeAppMetadata(bundleURL: self.tmpDir, bundleID: "com.example.myapp")
        let inFilename = self.scorer.score(self.url("com.example.myapp"), against: metadata)
        let inPath = self.scorer.score(
            self.tmpDir.appending(path: "com.example.myapp/data", directoryHint: .notDirectory),
            against: metadata
        )
        // Both should be high confidence, but the filename match rules specify 0.70 vs 0.50
        XCTAssertGreaterThanOrEqual(inFilename.score, inPath.score)
    }
}
