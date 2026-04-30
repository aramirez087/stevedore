import UISettingsUI
import XCTest

final class UISettingsUISmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UISettingsUIModule.moduleName, "UISettingsUI")
    }
}
