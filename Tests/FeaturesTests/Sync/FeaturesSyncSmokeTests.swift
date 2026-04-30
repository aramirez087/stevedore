import FeaturesSync
import XCTest

final class FeaturesSyncSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(FeaturesSyncModule.moduleName, "FeaturesSync")
    }
}
