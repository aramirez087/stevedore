import ServicesLogging
import XCTest

final class ServicesLoggingSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(ServicesLoggingModule.moduleName, "ServicesLogging")
    }
}
