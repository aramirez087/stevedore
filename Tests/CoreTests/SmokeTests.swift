@testable import Core
import XCTest

final class CoreSmokeTests: XCTestCase {
    func testFilePathRoot() {
        let root = FilePath.root(.local)
        XCTAssertTrue(root.isRoot)
        XCTAssertEqual(root.posixString, "/")
    }

    func testFilePathNormalization() {
        let path = FilePath(scheme: .local, posix: "/a/b/../c/./d")
        XCTAssertEqual(path.components, ["a", "c", "d"])
        XCTAssertEqual(path.posixString, "/a/c/d")
    }

    func testFileItemDisplayName() {
        let item = FileItem(
            path: FilePath(scheme: .local, posix: "/Users/test/notes.md"),
            kind: .regularFile
        )
        XCTAssertEqual(item.displayName, "notes.md")
    }

    func testStevedoreErrorCategory() {
        XCTAssertEqual(StevedoreError.cancelled.category, .app)
        XCTAssertEqual(StevedoreError.fileSystem(.notFound(.root(.local))).category, .fileSystem)
        XCTAssertEqual(StevedoreError.remote(.timeout).category, .remote)
    }
}
