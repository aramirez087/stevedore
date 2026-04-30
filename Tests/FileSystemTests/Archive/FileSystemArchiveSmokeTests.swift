import FileSystemArchive
import XCTest

final class FileSystemArchiveSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(FileSystemArchiveModule.moduleName, "FileSystemArchive")
    }
}
