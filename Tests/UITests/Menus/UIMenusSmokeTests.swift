import UIMenus
import XCTest

final class UIMenusSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UIMenusModule.moduleName, "UIMenus")
    }
}
