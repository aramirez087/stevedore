import DesignSystem
import XCTest

final class DesignSystemSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(DesignSystemModule.moduleName, "DesignSystem")
    }
}
