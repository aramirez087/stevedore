import Core
@testable import MainWindow
import XCTest

@MainActor
final class WindowStateTests: XCTestCase {
    func testDefaultSplitFractionIsHalf() {
        let state = WindowState()
        XCTAssertEqual(state.splitFraction, 0.5)
    }

    func testSplitFractionClampedBelowMinimum() {
        let state = WindowState()
        state.splitFraction = 0.05
        XCTAssertEqual(state.splitFraction, WindowState.minFraction)
    }

    func testSplitFractionClampedAboveMaximum() {
        let state = WindowState()
        state.splitFraction = 0.99
        XCTAssertEqual(state.splitFraction, WindowState.maxFraction)
    }

    func testWindowStateSnapshotCodableRoundTrip() throws {
        let tab = Tab(path: FilePath(scheme: .local, posix: "/Users/test/Documents"))
        let snapshot = WindowStateSnapshot(
            splitFraction: 0.4,
            leftTabs: [tab],
            leftActiveTabID: tab.id,
            rightTabs: [],
            rightActiveTabID: nil
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WindowStateSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testWindowStateSnapshotDefaultHasEmptyTabs() {
        let snap = WindowStateSnapshot.default
        XCTAssertTrue(snap.leftTabs.isEmpty)
        XCTAssertTrue(snap.rightTabs.isEmpty)
        XCTAssertNil(snap.leftActiveTabID)
        XCTAssertNil(snap.rightActiveTabID)
    }

    func testActivePaneDefaultsToLeft() {
        let state = WindowState()
        XCTAssertEqual(state.activePaneID, .left)
    }

    func testSplitFractionInRangeIsPreserved() {
        let state = WindowState(snapshot: WindowStateSnapshot(
            splitFraction: 0.65,
            leftTabs: [],
            leftActiveTabID: nil,
            rightTabs: [],
            rightActiveTabID: nil
        ))
        XCTAssertEqual(state.splitFraction, 0.65, accuracy: 0.001)
    }
}
