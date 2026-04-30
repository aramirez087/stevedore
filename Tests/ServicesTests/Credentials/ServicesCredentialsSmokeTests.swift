import ServicesCredentials
import XCTest

final class ServicesCredentialsSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(ServicesCredentialsModule.moduleName, "ServicesCredentials")
    }
}
