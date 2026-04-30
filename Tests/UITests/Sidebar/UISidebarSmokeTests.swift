import UISidebar
import XCTest

final class UISidebarSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UISidebarModule.moduleName, "UISidebar")
    }
}
