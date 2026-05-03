import UIMenus
import XCTest

@MainActor
final class WindowCommandProxyTests: XCTestCase {
    func testShowConnectDialogCallsClosure() {
        var called = false
        let proxy = WindowCommandProxy.makeStub(showConnectDialog: { called = true })
        proxy.showConnectDialog()
        XCTAssertTrue(called)
    }

    func testShowSyncDialogCallsClosure() {
        var called = false
        let proxy = WindowCommandProxy.makeStub(showSyncDialog: { called = true })
        proxy.showSyncDialog()
        XCTAssertTrue(called)
    }

    func testShowRenameDialogCallsClosure() {
        var called = false
        let proxy = WindowCommandProxy.makeStub(showRenameDialog: { called = true })
        proxy.showRenameDialog()
        XCTAssertTrue(called)
    }

    func testShowUninstallerDialogCallsClosure() {
        var called = false
        let proxy = WindowCommandProxy.makeStub(showUninstallerDialog: { called = true })
        proxy.showUninstallerDialog()
        XCTAssertTrue(called)
    }

    func testFocusSearchCallsClosure() {
        var called = false
        let proxy = WindowCommandProxy.makeStub(focusSearch: { called = true })
        proxy.focusSearch()
        XCTAssertTrue(called)
    }
}
