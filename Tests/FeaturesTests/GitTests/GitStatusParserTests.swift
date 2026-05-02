import Core
import FeaturesGit
import Foundation
import XCTest

final class GitStatusParserTests: XCTestCase {
    private let root = FilePath(scheme: .local, posix: "/repo")

    // MARK: - Helpers

    private func parse(_ ascii: String) -> [GitFileStatus] {
        GitStatusParser.parse(Data(ascii.utf8), repoRoot: self.root)
    }

    private func nul(_ tokens: String...) -> String {
        tokens.joined(separator: "\0")
    }

    private func path(_ name: String) -> FilePath {
        self.root.appending(posix: name)
    }

    // MARK: - Tests

    func testEmptyData() {
        XCTAssertEqual(self.parse(""), [])
    }

    func testHeaderLinesSkipped() {
        let input = self.nul(
            "# branch.oid abc123",
            "# branch.head main",
            "# branch.upstream origin/main",
            "# branch.ab +0 -0",
            ""
        )
        XCTAssertEqual(self.parse(input), [])
    }

    func testModifiedWorktree() {
        // `1 .M N... 100644 100644 100644 <hH> <hI> foo.txt`
        let input = self.nul("1 .M N... 100644 100644 100644 abc abc foo.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, self.path("foo.txt"))
        XCTAssertEqual(results[0].indexState, .unmodified)
        XCTAssertEqual(results[0].worktreeState, .modified)
    }

    func testStagedModification() {
        let input = self.nul("1 M. N... 100644 100644 100644 abc abc foo.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].indexState, .modified)
        XCTAssertEqual(results[0].worktreeState, .unmodified)
    }

    func testStagedAddition() {
        let input = self.nul("1 A. N... 0 100644 100644 0000000 abc new.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, self.path("new.txt"))
        XCTAssertEqual(results[0].indexState, .added)
        XCTAssertEqual(results[0].worktreeState, .unmodified)
    }

    func testDeletedInWorktree() {
        let input = self.nul("1 .D N... 100644 100644 0 abc 0000000 del.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].worktreeState, .deleted)
    }

    func testStagedDeletion() {
        let input = self.nul("1 D. N... 100644 0 0 abc 0000000 del.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].indexState, .deleted)
        XCTAssertEqual(results[0].worktreeState, .unmodified)
    }

    func testStagedRename() {
        // Type-2 record: two NUL-separated tokens.
        let input = self.nul("2 R. N... 100644 100644 100644 abc abc R100 new.txt", "old.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, self.path("new.txt"))
        XCTAssertEqual(results[0].indexState, .renamed)
        XCTAssertEqual(results[0].worktreeState, .unmodified)
    }

    func testWorktreeRename() {
        let input = self.nul("2 .R N... 100644 100644 100644 abc abc R100 new.txt", "old.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].indexState, .unmodified)
        XCTAssertEqual(results[0].worktreeState, .renamed)
    }

    func testUnmergedConflict() {
        // `u UU N... m1 m2 m3 mW h1 h2 h3 conflict.txt`
        let input = self.nul("u UU N... 100644 100644 100644 100644 abc abc abc conflict.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, self.path("conflict.txt"))
        XCTAssertEqual(results[0].indexState, .conflicted)
        XCTAssertEqual(results[0].worktreeState, .conflicted)
    }

    func testUntracked() {
        let input = self.nul("? untracked.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, self.path("untracked.txt"))
        XCTAssertEqual(results[0].worktreeState, .untracked)
    }

    func testIgnored() {
        let input = self.nul("! .DS_Store", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, self.path(".DS_Store"))
        XCTAssertEqual(results[0].worktreeState, .ignored)
    }

    func testTypeChanged() {
        let input = self.nul("1 .T N... 100644 120000 120000 abc abc link", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].worktreeState, .typeChanged)
    }

    func testSubmoduleWithWorktreeChanges() {
        // Submodule: sub field is `SC..` instead of `N...`
        let input = self.nul("1 .M SC.. 160000 160000 160000 abc abc sub/", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, self.path("sub/"))
        XCTAssertEqual(results[0].worktreeState, .modified)
    }

    func testMultipleEntriesInOneBlob() {
        let input = self.nul(
            "1 .M N... 100644 100644 100644 abc abc a.txt",
            "1 A. N... 0 100644 100644 0000000 abc b.txt",
            "? c.txt",
            "! d.log",
            ""
        )
        let results = self.parse(input)
        XCTAssertEqual(results.count, 4)
    }

    func testCopied() {
        let input = self.nul("2 C. N... 100644 100644 100644 abc abc C100 dest.txt", "src.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].indexState, .copied)
    }

    func testUnknownPrefixSkipped() {
        let input = self.nul("X something weird", "1 .M N... 100644 100644 100644 abc abc real.txt", "")
        let results = self.parse(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, self.path("real.txt"))
    }
}
