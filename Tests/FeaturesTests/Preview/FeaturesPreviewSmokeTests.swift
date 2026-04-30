import FeaturesPreview
import XCTest

final class FeaturesPreviewSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(FeaturesPreviewModule.moduleName, "FeaturesPreview")
    }
}
