import FeaturesUninstaller
import XCTest

final class FeaturesUninstallerSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(FeaturesUninstallerModule.moduleName, "FeaturesUninstaller")
    }
}
