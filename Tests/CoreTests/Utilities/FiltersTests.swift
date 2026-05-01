@testable import Core
import XCTest

final class FiltersTests: XCTestCase {
    // MARK: - Helpers

    private func item(
        name: String,
        kind: FileKind = .regularFile,
        hidden: Bool = false
    ) -> FileItem {
        FileItem(
            path: FilePath(scheme: .local, posix: "/\(name)"),
            kind: kind,
            attributes: FileAttributes(isHidden: hidden)
        )
    }

    // MARK: - Built-ins

    func testAny_alwaysTrue() {
        XCTAssertTrue(FileItemFilter.any(self.item(name: "x")))
    }

    func testNone_alwaysFalse() {
        XCTAssertFalse(FileItemFilter.none(self.item(name: "x")))
    }

    func testVisible_filtersHidden() {
        let visible = self.item(name: "normal", hidden: false)
        let hidden = self.item(name: ".hidden", hidden: true)
        XCTAssertTrue(FileItemFilter.visible(visible))
        XCTAssertFalse(FileItemFilter.visible(hidden))
    }

    func testHiddenOnly() {
        let visible = self.item(name: "normal", hidden: false)
        let hidden = self.item(name: ".hidden", hidden: true)
        XCTAssertFalse(FileItemFilter.hiddenOnly(visible))
        XCTAssertTrue(FileItemFilter.hiddenOnly(hidden))
    }

    func testKindFilter_directory() {
        let file = self.item(name: "f", kind: .regularFile)
        let dir = self.item(name: "d", kind: .directory)
        XCTAssertFalse(FileItemFilter.kind(.directory)(file))
        XCTAssertTrue(FileItemFilter.kind(.directory)(dir))
    }

    func testKindsFilter_multipleKinds() {
        let file = self.item(name: "f", kind: .regularFile)
        let dir = self.item(name: "d", kind: .directory)
        let link = self.item(name: "l", kind: .symbolicLink)
        let filter = FileItemFilter.kinds([.regularFile, .directory])
        XCTAssertTrue(filter(file))
        XCTAssertTrue(filter(dir))
        XCTAssertFalse(filter(link))
    }

    // MARK: - Combinators

    func testAnd_bothTrue() {
        let combined = FileItemFilter.visible.and(FileItemFilter.kind(.regularFile))
        XCTAssertTrue(combined(self.item(name: "f", kind: .regularFile, hidden: false)))
    }

    func testAnd_oneFalse() {
        let combined = FileItemFilter.visible.and(FileItemFilter.kind(.directory))
        XCTAssertFalse(combined(self.item(name: "f", kind: .regularFile, hidden: false)))
    }

    func testOr_bothFalse() {
        let combined = FileItemFilter.none.or(FileItemFilter.none)
        XCTAssertFalse(combined(self.item(name: "x")))
    }

    func testOr_oneTrue() {
        let combined = FileItemFilter.none.or(FileItemFilter.any)
        XCTAssertTrue(combined(self.item(name: "x")))
    }

    func testNegated() {
        XCTAssertFalse(FileItemFilter.any.negated()(self.item(name: "x")))
        XCTAssertTrue(FileItemFilter.none.negated()(self.item(name: "x")))
    }

    // MARK: - GlobMatcher: positive cases

    func testGlob_simpleExtension_matchesAnywhere() {
        let filter = FileItemFilter.glob("*.swift")
        let match = FileItem(
            path: FilePath(scheme: .local, posix: "/src/main.swift"),
            kind: .regularFile
        )
        XCTAssertTrue(filter(match))
    }

    func testGlob_questionMark_exactlyOneChar() {
        XCTAssertTrue(GlobMatcher.matches(pattern: "?.swift", path: "/a.swift"))
        XCTAssertFalse(GlobMatcher.matches(pattern: "?.swift", path: "/ab.swift"))
    }

    func testGlob_doubleStarRecurses() {
        XCTAssertTrue(GlobMatcher.matches(pattern: "**/*.swift", path: "/src/lib/main.swift"))
        XCTAssertTrue(GlobMatcher.matches(pattern: "**/*.swift", path: "/main.swift"))
    }

    // MARK: - GlobMatcher: negative cases (exit criteria)

    func testGlob_singleStarWithExplicitDir_doesNotCrossSlash() {
        // "src/*.swift" has a `/` so no **/prefix is added.
        // The single `*` must NOT cross into a nested directory.
        XCTAssertFalse(GlobMatcher.matches(pattern: "src/*.swift", path: "/src/sub/foo.swift"))
    }

    func testGlob_singleStarBakExtension() {
        // "*.swift" (prefixed → **/*.swift) must NOT match "foo.swift.bak"
        XCTAssertFalse(GlobMatcher.matches(pattern: "*.swift", path: "/foo.swift.bak"))
    }

    func testGlob_questionMark_negativeMultiChar() {
        XCTAssertFalse(GlobMatcher.matches(pattern: "?.swift", path: "/ab.swift"))
    }

    func testGlob_singleStarAlone_matchesAnyLastComponent() {
        // "*" → "**/∗" — matches any single path component anywhere in the tree.
        XCTAssertTrue(GlobMatcher.matches(pattern: "*", path: "/a/b"))
    }

    func testGlob_singleStarWithSlash_doesNotMatchNestedPath() {
        // Pattern with explicit "/" → no ergonomic prefix. "/*" must only match top-level names.
        XCTAssertFalse(GlobMatcher.matches(pattern: "/*.swift", path: "/a/b.swift"))
    }

    // MARK: - GlobMatcher: case sensitivity

    func testGlob_caseSensitive_noMatch() {
        XCTAssertFalse(GlobMatcher.matches(pattern: "*.SWIFT", path: "/main.swift", caseSensitive: true))
    }

    func testGlob_caseInsensitive_matches() {
        XCTAssertTrue(GlobMatcher.matches(pattern: "*.SWIFT", path: "/main.swift", caseSensitive: false))
    }

    // MARK: - GlobMatcher: edge cases

    func testGlob_emptyPattern_matchesRoot() {
        // Empty pattern: no `/` so prefix is `**/`, which matches everything.
        XCTAssertTrue(GlobMatcher.matches(pattern: "**", path: "/a/b"))
    }

    func testGlob_deepNesting() {
        XCTAssertTrue(GlobMatcher.matches(pattern: "**/deep/*.txt", path: "/a/b/c/deep/note.txt"))
    }
}
