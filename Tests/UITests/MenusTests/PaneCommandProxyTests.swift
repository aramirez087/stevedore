import Core
import UIMenus
import XCTest

@MainActor
final class PaneCommandProxyTests: XCTestCase {
    func testGoBackCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(goBack: { called = true })
        proxy.goBack()
        XCTAssertTrue(called)
    }

    func testGoForwardCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(goForward: { called = true })
        proxy.goForward()
        XCTAssertTrue(called)
    }

    func testGoUpCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(goUp: { called = true })
        proxy.goUp()
        XCTAssertTrue(called)
    }

    func testGoHomeCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(goHome: { called = true })
        proxy.goHome()
        XCTAssertTrue(called)
    }

    func testGoToComputerCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(goToComputer: { called = true })
        proxy.goToComputer()
        XCTAssertTrue(called)
    }

    func testNewFolderCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(newFolder: { called = true })
        proxy.newFolder()
        XCTAssertTrue(called)
    }

    func testOpenInTerminalCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(openInTerminal: { called = true })
        proxy.openInTerminal()
        XCTAssertTrue(called)
    }

    func testNewTabCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(openNewTab: { called = true })
        proxy.openNewTab()
        XCTAssertTrue(called)
    }

    func testCloseTabCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(closeActiveTab: { called = true })
        proxy.closeActiveTab()
        XCTAssertTrue(called)
    }

    func testNextTabCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(nextTab: { called = true })
        proxy.nextTab()
        XCTAssertTrue(called)
    }

    func testPreviousTabCallsClosure() {
        var called = false
        let proxy = PaneCommandProxy.makeStub(previousTab: { called = true })
        proxy.previousTab()
        XCTAssertTrue(called)
    }

    func testIsRemoteReadOnlyDefaultsFalse() {
        let proxy = PaneCommandProxy.makeStub()
        XCTAssertFalse(proxy.isRemoteReadOnly)
    }

    func testIsRemoteReadOnlyTrueWhenSet() {
        let proxy = PaneCommandProxy.makeStub(isRemoteReadOnly: true)
        XCTAssertTrue(proxy.isRemoteReadOnly)
    }

    func testCanGoBackReflectsConstructedValue() {
        let yes = PaneCommandProxy.makeStub(canGoBack: true)
        let no = PaneCommandProxy.makeStub(canGoBack: false)
        XCTAssertTrue(yes.canGoBack)
        XCTAssertFalse(no.canGoBack)
    }

    func testCanGoForwardReflectsConstructedValue() {
        let yes = PaneCommandProxy.makeStub(canGoForward: true)
        let no = PaneCommandProxy.makeStub(canGoForward: false)
        XCTAssertTrue(yes.canGoForward)
        XCTAssertFalse(no.canGoForward)
    }
}
