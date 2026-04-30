import FileSystemRemote
import XCTest

final class FileSystemRemoteSmokeTests: XCTestCase {
    func testModuleNameSentinel() {
        XCTAssertEqual(FileSystemRemoteModule.moduleName, "FileSystemRemote")
    }
}
