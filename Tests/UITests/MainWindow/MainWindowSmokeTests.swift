import MainWindow
import XCTest

final class MainWindowSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(MainWindowModule.moduleName, "MainWindow")
    }
}
