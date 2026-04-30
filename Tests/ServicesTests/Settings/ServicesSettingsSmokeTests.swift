import ServicesSettings
import XCTest

final class ServicesSettingsSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(ServicesSettingsModule.moduleName, "ServicesSettings")
    }
}
