import AppKit
import Core
import FeaturesOperations
@testable import MainWindow
import SwiftUI
import XCTest

@MainActor
final class MainWindowTests: XCTestCase {
    // MARK: - PaneSession

    func testPaneSessionInitHasSingleTab() {
        let session = makeTestPaneSession()
        XCTAssertEqual(session.tabs.count, 1)
        XCTAssertNotNil(session.activeTabID)
    }

    func testPaneSessionNavigateUpdatesCurrentPath() {
        let session = makeTestPaneSession()
        let newPath = FilePath(scheme: .local, posix: "/Users/test/Downloads")
        session.navigate(to: newPath)
        XCTAssertEqual(session.currentPath, newPath)
    }

    func testPaneSessionNavigateKeepsToolbarPathInSync() {
        let session = makeTestPaneSession()
        let newPath = FilePath(scheme: .local, posix: "/Users/test/Desktop")
        session.navigate(to: newPath)
        XCTAssertEqual(session.toolbarViewModel.currentPath, newPath)
    }

    func testPaneSessionOpenTabAddsTabs() {
        let session = makeTestPaneSession()
        let extra = FilePath(scheme: .local, posix: "/tmp")
        session.openTab(at: extra)
        XCTAssertEqual(session.tabs.count, 2)
    }

    func testPaneSessionCloseTabRemovesTab() {
        let session = makeTestPaneSession()
        let extra = FilePath(scheme: .local, posix: "/tmp")
        session.openTab(at: extra)
        XCTAssertEqual(session.tabs.count, 2)
        let tabToClose = session.tabs[0].id
        session.closeTab(tabToClose)
        XCTAssertEqual(session.tabs.count, 1)
    }

    func testPaneSessionCloseLastTabIsNoOp() {
        let session = makeTestPaneSession()
        XCTAssertEqual(session.tabs.count, 1)
        let onlyTab = session.tabs[0].id
        session.closeTab(onlyTab)
        XCTAssertEqual(session.tabs.count, 1)
    }

    func testPaneSessionActivateTabNavigates() {
        let session = makeTestPaneSession()
        let extra = FilePath(scheme: .local, posix: "/var")
        session.openTab(at: extra)
        let firstTabID = session.tabs[0].id
        session.activateTab(firstTabID)
        XCTAssertEqual(session.activeTabID, firstTabID)
    }

    // MARK: - MainWindowModel

    func testDropOntoOppositePaneEnqueuesOperation() async {
        let model = makeTestMainWindowModel()
        let paths = [FilePath(scheme: .local, posix: "/Users/test/file.txt")]

        var received: [[FeaturesOperations.Operation]] = []
        let task = Task {
            for await ops in model.operationQueue.operationStream() {
                received.append(ops)
                if !ops.isEmpty { break }
            }
        }

        model.handleDrop(paths, onto: .right)
        await task.value

        XCTAssertFalse(received.filter { !$0.isEmpty }.isEmpty)
    }

    func testActivePaneSwitchesOnActivate() {
        let model = makeTestMainWindowModel()
        XCTAssertEqual(model.windowState.activePaneID, .left)
        model.windowState.activePaneID = .right
        XCTAssertEqual(model.windowState.activePaneID, .right)
        XCTAssertIdentical(model.activePaneSession, model.rightSession)
    }

    func testWindowStateRoundTrip() {
        let model = makeTestMainWindowModel()
        let original = model.windowState.splitFraction
        model.windowState.splitFraction = 0.35
        XCTAssertEqual(model.windowState.splitFraction, 0.35, accuracy: 0.001)
        model.windowState.splitFraction = original
        XCTAssertEqual(model.windowState.splitFraction, original, accuracy: 0.001)
    }

    // MARK: - Composition smoke test

    func testMainWindowViewComposesWithoutCrashing() {
        let model = makeTestMainWindowModel()
        let view = MainWindowView(model: model)
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }
}
