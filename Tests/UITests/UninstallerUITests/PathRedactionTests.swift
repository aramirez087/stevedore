import UIUninstallerUI
import XCTest

/// Verifies that home-directory paths are redacted with `~` in the table display.
@MainActor
final class UninstallerUIPathRedactionTests: XCTestCase {
    func testHomeDirectoryPrefixReplacedWithTilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = home + "/Library/Application Support/com.example.App"
        let result = AssociatedFilesTable.redactHome(path)
        XCTAssertTrue(result.hasPrefix("~/"), "Home prefix must be replaced with ~/")
        XCTAssertFalse(result.contains(home), "Raw home path must not appear in redacted output")
    }

    func testNonHomePathPassedThrough() {
        let path = "/Library/Application Support/com.example.App"
        let result = AssociatedFilesTable.redactHome(path)
        XCTAssertEqual(result, path, "Non-home paths must pass through unchanged")
    }

    func testHomeRootItself() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let result = AssociatedFilesTable.redactHome(home)
        XCTAssertEqual(result, "~", "The home directory itself should redact to just ~")
    }

    func testDeepNestedPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = home + "/Library/Containers/com.example.App/Data/Library/Preferences/com.example.App.plist"
        let result = AssociatedFilesTable.redactHome(path)
        XCTAssertTrue(result.hasPrefix("~/Library/Containers/"))
    }
}
