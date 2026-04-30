import UIToolbar
import XCTest

final class UIToolbarSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UIToolbarModule.moduleName, "UIToolbar")
    }
}
