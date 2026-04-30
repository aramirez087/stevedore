import FeaturesRename
import XCTest

final class FeaturesRenameSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(FeaturesRenameModule.moduleName, "FeaturesRename")
    }
}
