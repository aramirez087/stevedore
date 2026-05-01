import FeaturesRename
import XCTest

final class RenameStepTests: XCTestCase {
    // MARK: - find

    func testFindBasic() throws {
        let result = try applyStep(.find(text: "world", replace: "swift", caseSensitive: true), to: "hello world.txt")
        XCTAssertEqual(result, "hello swift.txt")
    }

    func testFindCaseInsensitive() throws {
        let result = try applyStep(.find(text: "hello", replace: "hi", caseSensitive: false), to: "Hello.txt")
        XCTAssertEqual(result, "hi.txt")
    }

    func testFindCaseSensitiveMiss() throws {
        let result = try applyStep(.find(text: "hello", replace: "hi", caseSensitive: true), to: "Hello.txt")
        XCTAssertEqual(result, "Hello.txt")
    }

    func testFindNoMatch() throws {
        let result = try applyStep(.find(text: "xyz", replace: "abc", caseSensitive: true), to: "hello.txt")
        XCTAssertEqual(result, "hello.txt")
    }

    // MARK: - regex

    func testRegexSimplePattern() throws {
        let result = try applyStep(.regex(pattern: "IMG_(\\d+)", replacement: "photo_$1"), to: "IMG_1234.jpg")
        XCTAssertEqual(result, "photo_1234.jpg")
    }

    func testRegexBackreference() throws {
        let result = try applyStep(
            .regex(pattern: "(\\w+)_(\\w+)", replacement: "$2_$1"),
            to: "hello_world.txt"
        )
        XCTAssertEqual(result, "world_hello.txt")
    }

    // MARK: - case

    func testCaseLower() throws {
        let result = try applyStep(.case(.lower), to: "HELLO.TXT")
        XCTAssertEqual(result, "hello.TXT")
    }

    func testCaseUpper() throws {
        let result = try applyStep(.case(.upper), to: "hello.txt")
        XCTAssertEqual(result, "HELLO.txt")
    }

    func testCaseTitle() throws {
        let result = try applyStep(.case(.title), to: "hello world.txt")
        XCTAssertEqual(result, "Hello World.txt")
    }

    func testCasePreserve() throws {
        let result = try applyStep(.case(.preserve), to: "Hello.txt")
        XCTAssertEqual(result, "Hello.txt")
    }

    func testCaseUnicode() throws {
        let result = try applyStep(.case(.upper), to: "café.txt")
        XCTAssertEqual(result, "CAFÉ.txt")
    }

    // MARK: - trim

    func testTrimLeading() throws {
        let result = try applyStep(.trim(.leading), to: "  hello  .txt")
        XCTAssertEqual(result, "hello  .txt")
    }

    func testTrimTrailing() throws {
        let result = try applyStep(.trim(.trailing), to: "  hello  .txt")
        XCTAssertEqual(result, "  hello.txt")
    }

    func testTrimBoth() throws {
        let result = try applyStep(.trim(.both), to: "  hello  .txt")
        XCTAssertEqual(result, "hello.txt")
    }

    // MARK: - insert

    func testInsertPrefix() throws {
        let result = try applyStep(.insert(text: "NEW_", at: .prefix), to: "photo.jpg")
        XCTAssertEqual(result, "NEW_photo.jpg")
    }

    func testInsertSuffix() throws {
        let result = try applyStep(.insert(text: "_edited", at: .suffix), to: "photo.jpg")
        XCTAssertEqual(result, "photo_edited.jpg")
    }

    func testInsertBeforeExtension() throws {
        let result = try applyStep(.insert(text: "_v2", at: .beforeExtension), to: "photo.jpg")
        XCTAssertEqual(result, "photo_v2.jpg")
    }

    func testInsertIndex() throws {
        let result = try applyStep(.insert(text: "X", at: .index(1)), to: "hello.txt")
        XCTAssertEqual(result, "hXello.txt")
    }

    func testInsertIndexBeyondEnd() throws {
        let result = try applyStep(.insert(text: "X", at: .index(100)), to: "hello.txt")
        XCTAssertEqual(result, "helloX.txt")
    }

    // MARK: - sequence

    func testSequencePrefix() throws {
        let result = try applyStep(.sequence(start: 1, padding: 3, position: .prefix), to: "photo.jpg")
        XCTAssertEqual(result, "001photo.jpg")
    }

    func testSequenceSuffix() throws {
        let result = try applyStep(.sequence(start: 1, padding: 3, position: .suffix), to: "photo.jpg")
        XCTAssertEqual(result, "photo001.jpg")
    }

    func testSequenceReplace() throws {
        let result = try applyStep(.sequence(start: 1, padding: 3, position: .replace), to: "photo.jpg")
        XCTAssertEqual(result, "001.jpg")
    }

    func testSequencePaddingExact() throws {
        let result = try applyStep(.sequence(start: 1, padding: 3, position: .prefix), to: "a.txt")
        XCTAssertEqual(result, "001a.txt")
    }

    func testSequencePaddingOverflow() throws {
        let result = try applyStep(.sequence(start: 1000, padding: 2, position: .prefix), to: "a.txt")
        XCTAssertEqual(result, "1000a.txt")
    }

    func testSequenceMultipleItems() throws {
        let step = RenameStep.sequence(start: 1, padding: 3, position: .prefix)
        var stem0 = "photo", ext0: String? = "jpg"
        var stem1 = "photo", ext1: String? = "jpg"
        try step.apply(to: &stem0, ext: &ext0, index: 0)
        try step.apply(to: &stem1, ext: &ext1, index: 1)
        XCTAssertEqual(testAssembled(stem: stem0, ext: ext0), "001photo.jpg")
        XCTAssertEqual(testAssembled(stem: stem1, ext: ext1), "002photo.jpg")
    }

    // MARK: - extension

    func testExtensionLower() throws {
        let result = try applyStep(.extension(.lower), to: "photo.JPG")
        XCTAssertEqual(result, "photo.jpg")
    }

    func testExtensionUpper() throws {
        let result = try applyStep(.extension(.upper), to: "photo.jpg")
        XCTAssertEqual(result, "photo.JPG")
    }

    func testExtensionPreserve() throws {
        let result = try applyStep(.extension(.preserve), to: "photo.jpg")
        XCTAssertEqual(result, "photo.jpg")
    }

    func testExtensionOnHiddenFile() throws {
        let result = try applyStep(.extension(.lower), to: ".gitignore")
        XCTAssertEqual(result, ".gitignore")
    }

    // MARK: - edge cases

    func testVeryLongStem() throws {
        let longStem = String(repeating: "a", count: 500)
        let result = try applyStep(.case(.upper), to: "\(longStem).txt")
        XCTAssertEqual(result.count, 504)
    }

    func testEmptyStemAfterTrim() throws {
        var stem = "   "
        var ext: String? = "txt"
        try RenameStep.trim(.both).apply(to: &stem, ext: &ext, index: 0)
        XCTAssertEqual(stem, "")
        XCTAssertEqual(ext, "txt")
    }
}
