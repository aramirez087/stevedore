import Core
@testable import FeaturesPreview
import Foundation
import XCTest

final class CodePreviewRendererTests: XCTestCase {
    func testSwiftExtensionDetectsSwift() {
        XCTAssertEqual(Language.detect(extension: "swift"), .swift)
    }

    func testPythonExtensionDetectsPython() {
        XCTAssertEqual(Language.detect(extension: "py"), .python)
        XCTAssertEqual(Language.detect(extension: "pyw"), .python)
    }

    func testUnknownExtensionIsUnknown() {
        XCTAssertEqual(Language.detect(extension: "xyz"), .unknown)
        XCTAssertEqual(Language.detect(extension: ""), .unknown)
    }

    func testAllSupportedExtensionsMapToNonUnknown() {
        let knownExtensions = [
            "swift", "py", "pyw", "js", "mjs", "ts", "tsx",
            "java", "go", "rs", "c", "cpp", "cc", "cxx",
            "m", "mm", "rb", "sh", "bash", "zsh",
            "html", "htm", "css", "json", "xml", "plist",
            "yaml", "yml", "sql", "h", "hpp",
        ]
        for ext in knownExtensions {
            let lang = Language.detect(extension: ext)
            XCTAssertNotEqual(lang, .unknown, "Extension '\(ext)' should not map to .unknown")
        }
    }

    func testSwiftKeywordsNonEmpty() {
        XCTAssertFalse(Language.swift.keywords.isEmpty)
        XCTAssertTrue(Language.swift.keywords.contains("func"))
        XCTAssertTrue(Language.swift.keywords.contains("struct"))
    }

    func testUnknownLanguageHasNoKeywords() {
        XCTAssertTrue(Language.unknown.keywords.isEmpty)
    }

    func testCodeRendererReturnsRtfMimeType() async throws {
        let source = "func greet() { print(\"hello\") }"
        let url = try makeTempFile(name: "code.swift", text: source)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = await CodePreviewRenderer.render(item: item)
        XCTAssertEqual(payload?.mimeType, "text/rtf")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testUnknownLanguageFallsBackToPlainText() async throws {
        let source = "some unknown content"
        let url = try makeTempFile(name: "file.xyz", text: source)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = await CodePreviewRenderer.render(item: item)
        // Should not crash; returns non-nil RTF (plain monospaced text).
        XCTAssertNotNil(payload)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testNonLocalReturnsNil() async {
        let item = FileItem(
            path: FilePath(scheme: .sftp, posix: "/remote/file.swift"),
            kind: .regularFile
        )
        let payload = await CodePreviewRenderer.render(item: item)
        XCTAssertNil(payload)
    }

    func testEmptyFileProducesNonNilPayload() async throws {
        let url = try makeTempFile(name: "empty.swift", content: Data())
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = await CodePreviewRenderer.render(item: item)
        XCTAssertNotNil(payload)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
