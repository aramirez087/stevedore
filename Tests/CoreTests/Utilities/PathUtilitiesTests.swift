@testable import Core
import XCTest

final class PathUtilitiesTests: XCTestCase {
    // MARK: - relative(to:)

    func testRelative_exactMatch_returnsEmpty() {
        let path = FilePath(scheme: .local, posix: "/a/b")
        XCTAssertEqual(path.relative(to: path), [])
    }

    func testRelative_childToParent_returnsRemainder() {
        let base = FilePath(scheme: .local, posix: "/a/b")
        let child = FilePath(scheme: .local, posix: "/a/b/c/d")
        XCTAssertEqual(child.relative(to: base), ["c", "d"])
    }

    func testRelative_differentScheme_returnsNil() {
        let local = FilePath(scheme: .local, posix: "/a/b")
        let sftp = FilePath(scheme: .sftp, posix: "/a/b")
        XCTAssertNil(local.relative(to: sftp))
    }

    func testRelative_notAncestor_returnsNil() {
        let base = FilePath(scheme: .local, posix: "/x/y")
        let path = FilePath(scheme: .local, posix: "/a/b/c")
        XCTAssertNil(path.relative(to: base))
    }

    func testRelative_rootToRoot_returnsEmpty() {
        let root = FilePath.root(.local)
        XCTAssertEqual(root.relative(to: root), [])
    }

    func testRelative_siblingPath_returnsNil() {
        let base = FilePath(scheme: .local, posix: "/a/b")
        let sibling = FilePath(scheme: .local, posix: "/a/c")
        XCTAssertNil(sibling.relative(to: base))
    }

    // MARK: - relativePosix(to:)

    func testRelativePosix_childToParent() {
        let base = FilePath(scheme: .local, posix: "/a")
        let child = FilePath(scheme: .local, posix: "/a/b/c")
        XCTAssertEqual(child.relativePosix(to: base), "b/c")
    }

    func testRelativePosix_exactMatch_returnsEmptyString() {
        let path = FilePath(scheme: .local, posix: "/a/b")
        XCTAssertEqual(path.relativePosix(to: path), "")
    }

    // MARK: - commonAncestor

    func testCommonAncestor_differentSchemes_returnsNil() {
        let a = FilePath(scheme: .local, posix: "/a/b")
        let b = FilePath(scheme: .sftp, posix: "/a/b")
        XCTAssertNil(FilePath.commonAncestor(a, b))
    }

    func testCommonAncestor_twoRoots_returnsRoot() {
        let root1 = FilePath.root(.sftp)
        let root2 = FilePath(scheme: .sftp, posix: "/a")
        let ancestor = FilePath.commonAncestor(root1, root2)
        XCTAssertEqual(ancestor, FilePath.root(.sftp))
    }

    func testCommonAncestor_siblings_returnsParent() {
        let a = FilePath(scheme: .local, posix: "/a/b/c")
        let b = FilePath(scheme: .local, posix: "/a/b/d")
        XCTAssertEqual(FilePath.commonAncestor(a, b), FilePath(scheme: .local, posix: "/a/b"))
    }

    func testCommonAncestor_oneIsAncestorOfOther() {
        let parent = FilePath(scheme: .local, posix: "/a/b")
        let child = FilePath(scheme: .local, posix: "/a/b/c")
        XCTAssertEqual(FilePath.commonAncestor(parent, child), parent)
    }

    func testCommonAncestor_identical_returnsSelf() {
        let path = FilePath(scheme: .local, posix: "/a/b")
        XCTAssertEqual(FilePath.commonAncestor(path, path), path)
    }

    func testCommonAncestor_noSharedComponents_returnsRoot() {
        let a = FilePath(scheme: .local, posix: "/x/y")
        let b = FilePath(scheme: .local, posix: "/z/w")
        XCTAssertEqual(FilePath.commonAncestor(a, b), FilePath.root(.local))
    }

    // MARK: - appending(posix:)

    func testAppendingPosix_singleSegment() {
        let base = FilePath(scheme: .local, posix: "/a/b")
        XCTAssertEqual(base.appending(posix: "c"), FilePath(scheme: .local, posix: "/a/b/c"))
    }

    func testAppendingPosix_multiSegment() {
        let base = FilePath(scheme: .local, posix: "/a")
        XCTAssertEqual(base.appending(posix: "b/c"), FilePath(scheme: .local, posix: "/a/b/c"))
    }

    func testAppendingPosix_dotDotNormalized() {
        let base = FilePath(scheme: .local, posix: "/a/b/c")
        XCTAssertEqual(base.appending(posix: "../d"), FilePath(scheme: .local, posix: "/a/b/d"))
    }

    // MARK: - displayName

    func testDisplayName_nonRoot() {
        let path = FilePath(scheme: .local, posix: "/a/b/file.txt")
        XCTAssertEqual(path.displayName, "file.txt")
    }

    func testDisplayName_root_includesScheme() {
        let root = FilePath.root(.sftp)
        XCTAssertEqual(root.displayName, "sftp:/")
    }

    // MARK: - localizedDisplayNameCompare

    func testLocalizedCompare_numericOrdering() {
        let locale = Locale(identifier: "en_US_POSIX")
        let a = FilePath(scheme: .local, posix: "/file2")
        let b = FilePath(scheme: .local, posix: "/file10")
        let result = FilePath.localizedDisplayNameCompare(a, b, locale: locale)
        XCTAssertEqual(result, .orderedAscending)
    }

    // MARK: - from(urlString:)

    func testFromURLString_localFile() {
        let path = FilePath.from(urlString: "file:///a/b/c")
        XCTAssertEqual(path, FilePath(scheme: .local, posix: "/a/b/c"))
    }

    func testFromURLString_sftp() {
        let path = FilePath.from(urlString: "sftp://host/dir/file")
        XCTAssertEqual(path?.scheme, .sftp)
        XCTAssertEqual(path?.components, ["dir", "file"])
    }

    func testFromURLString_webdavHttp() {
        let path = FilePath.from(urlString: "http://server/share/file")
        XCTAssertEqual(path?.scheme, .webdav)
    }

    func testFromURLString_unknownScheme_returnsNil() {
        XCTAssertNil(FilePath.from(urlString: "gopher://host/path"))
    }

    func testFromURLString_invalidURL_returnsNil() {
        XCTAssertNil(FilePath.from(urlString: "not a url !!"))
    }

    func testFromURLString_s3() {
        let path = FilePath.from(urlString: "s3://bucket/prefix/key")
        XCTAssertEqual(path?.scheme, .s3)
    }

    func testFromURLString_smb() {
        let path = FilePath.from(urlString: "smb://server/share")
        XCTAssertEqual(path?.scheme, .smb)
    }

    func testFromURLString_ftpScheme() {
        let path = FilePath.from(urlString: "ftp://server/pub/file.zip")
        XCTAssertEqual(path?.scheme, .ftp)
    }

    func testFromURLString_httpsIsWebdav() {
        let path = FilePath.from(urlString: "https://dav.example.com/files")
        XCTAssertEqual(path?.scheme, .webdav)
    }

    // MARK: - Deep path edge cases

    func testRelative_deepPath() {
        let base = FilePath(scheme: .local, posix: "/a")
        let deep = FilePath(scheme: .local, posix: "/a/b/c/d/e/f")
        XCTAssertEqual(deep.relative(to: base), ["b", "c", "d", "e", "f"])
    }

    func testRelative_baseIsRoot() {
        let root = FilePath.root(.local)
        let path = FilePath(scheme: .local, posix: "/a/b")
        XCTAssertEqual(path.relative(to: root), ["a", "b"])
    }

    func testCommonAncestor_deepDivergence() {
        let a = FilePath(scheme: .local, posix: "/a/b/c/x/y")
        let b = FilePath(scheme: .local, posix: "/a/b/c/p/q")
        XCTAssertEqual(FilePath.commonAncestor(a, b), FilePath(scheme: .local, posix: "/a/b/c"))
    }

    func testRelativePosix_differentScheme_returnsNil() {
        let a = FilePath(scheme: .local, posix: "/a/b")
        let b = FilePath(scheme: .s3, posix: "/a")
        XCTAssertNil(a.relativePosix(to: b))
    }

    func testDisplayName_singleComponent() {
        let path = FilePath(scheme: .local, posix: "/Documents")
        XCTAssertEqual(path.displayName, "Documents")
    }

    func testDisplayName_rootVariousSchemes() {
        for scheme in ConnectionScheme.allCases {
            let root = FilePath.root(scheme)
            XCTAssertEqual(root.displayName, "\(scheme.rawValue):/")
        }
    }
}
