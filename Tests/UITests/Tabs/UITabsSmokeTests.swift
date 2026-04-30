import UITabs
import XCTest

final class UITabsSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UITabsModule.moduleName, "UITabs")
    }
}
