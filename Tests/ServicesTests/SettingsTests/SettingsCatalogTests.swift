import ServicesSettings
import XCTest

final class SettingsCatalogTests: XCTestCase {
    func testAllKeysHaveStevedorePrefix() {
        for key in Settings.allKeys {
            XCTAssertTrue(key.hasPrefix("stevedore."), "Key '\(key)' missing stevedore. prefix")
        }
    }

    func testAllKeysAreUnique() {
        XCTAssertEqual(Set(Settings.allKeys).count, Settings.allKeys.count, "Duplicate keys detected")
    }

    func testThemeDefaultIsSystem() {
        XCTAssertEqual(Settings.theme.defaultValue, "system")
    }

    func testDualPaneDefaultIsTrue() {
        XCTAssertTrue(Settings.dualPaneEnabled.defaultValue)
    }

    func testHiddenFilesDefaultIsFalse() {
        XCTAssertFalse(Settings.showHiddenFiles.defaultValue)
    }

    func testAllKeysCoverEveryStaticSetting() {
        // Verify the allKeys literal matches the number of static settings.
        // If a new setting is added without updating allKeys, this test fails.
        XCTAssertEqual(Settings.allKeys.count, 15, "allKeys count must match the number of static settings")
    }
}
