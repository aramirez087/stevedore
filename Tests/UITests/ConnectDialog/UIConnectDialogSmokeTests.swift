import UIConnectDialog
import XCTest

final class UIConnectDialogSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UIConnectDialogModule.moduleName, "UIConnectDialog")
    }
}
