import FeaturesOperations
import XCTest

final class FeaturesOperationsSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(FeaturesOperationsModule.moduleName, "FeaturesOperations")
    }
}
