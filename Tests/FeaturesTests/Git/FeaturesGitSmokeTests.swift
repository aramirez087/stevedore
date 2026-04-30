import FeaturesGit
import XCTest

final class FeaturesGitSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(FeaturesGitModule.moduleName, "FeaturesGit")
    }
}
