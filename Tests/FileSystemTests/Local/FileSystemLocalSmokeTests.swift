import FileSystemLocal
import XCTest

final class FileSystemLocalSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(FileSystemLocalModule.moduleName, "FileSystemLocal")
    }
}
