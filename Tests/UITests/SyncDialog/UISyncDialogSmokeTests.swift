import UISyncDialog
import XCTest

final class UISyncDialogSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UISyncDialogModule.moduleName, "UISyncDialog")
    }
}
