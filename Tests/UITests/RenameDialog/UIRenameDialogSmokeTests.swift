import UIRenameDialog
import XCTest

final class UIRenameDialogSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UIRenameDialogModule.moduleName, "UIRenameDialog")
    }
}
