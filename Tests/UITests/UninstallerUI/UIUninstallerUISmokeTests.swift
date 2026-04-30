import UIUninstallerUI
import XCTest

final class UIUninstallerUISmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UIUninstallerUIModule.moduleName, "UIUninstallerUI")
    }
}
