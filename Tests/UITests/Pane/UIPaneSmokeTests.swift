import UIPane
import XCTest

final class UIPaneSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UIPaneModule.moduleName, "UIPane")
    }
}
