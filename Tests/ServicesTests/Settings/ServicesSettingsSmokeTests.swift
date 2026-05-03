import ServicesSettings
import XCTest

final class ServicesSettingsSmokeTests: XCTestCase {
    func testCatalogHasEntries() {
        XCTAssertEqual(Settings.theme.key, "stevedore.theme")
        XCTAssertEqual(Settings.showHiddenFiles.defaultValue, false)
    }
}
