import UITransfers
import XCTest

final class UITransfersSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(UITransfersModule.moduleName, "UITransfers")
    }
}
