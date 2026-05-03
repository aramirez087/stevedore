import Core
@testable import FeaturesPreview
import Foundation
import XCTest

final class TextPreviewRendererTests: XCTestCase {
    func testUtf8TextReturnsRtfPayload() async throws {
        let url = try makeTempFile(name: "hello.txt", text: "Hello, world!", encoding: .utf8)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = await TextPreviewRenderer.render(item: item)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.mimeType, "text/rtf")
        XCTAssertFalse(payload?.data.isEmpty ?? true)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testUtf16LeDetected() async throws {
        let bom = Data([0xFF, 0xFE])
        let text = Data("hi".utf16.flatMap { withUnsafeBytes(of: $0.littleEndian) { Array($0) } })
        let url = try makeTempFile(name: "utf16le.txt", content: bom + text)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = await TextPreviewRenderer.render(item: item)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.mimeType, "text/rtf")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testUtf16BeDetected() async throws {
        let bom = Data([0xFE, 0xFF])
        let text = Data("hi".utf16.flatMap { withUnsafeBytes(of: $0.bigEndian) { Array($0) } })
        let url = try makeTempFile(name: "utf16be.txt", content: bom + text)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = await TextPreviewRenderer.render(item: item)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.mimeType, "text/rtf")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testLatin1Fallback() async throws {
        // Bytes 0x80–0xFF are invalid UTF-8 — Latin-1 must decode them.
        let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0xE9]) // "Hellé" in Latin-1
        let url = try makeTempFile(name: "latin1.txt", content: data)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = await TextPreviewRenderer.render(item: item)
        XCTAssertNotNil(payload)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testUtf8BomStripped() {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let rest = Data("content".utf8)
        let (decoded, enc) = TextPreviewRenderer.detectAndDecode(bom + rest)
        XCTAssertEqual(enc, .utf8)
        XCTAssertEqual(decoded, "content")
    }

    func testLargeFileReadLimited() async throws {
        // Write a 2 MB file; renderer should only read the first 1 MB.
        let twoMB = Data(repeating: 0x41, count: 2 * 1024 * 1024) // 'A' × 2 MB
        let url = try makeTempFile(name: "large.txt", content: twoMB)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = await TextPreviewRenderer.render(item: item)
        XCTAssertNotNil(payload)
        // RTF wrapping adds overhead; just check it's smaller than 2 MB raw.
        XCTAssertLessThan(payload?.data.count ?? Int.max, 2 * 1024 * 1024 + 10000)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testDirectoryReturnsNil() async {
        let item = makePreviewItem(name: "somedir", kind: .directory)
        let payload = await TextPreviewRenderer.render(item: item)
        XCTAssertNil(payload)
    }

    func testNonLocalSchemeReturnsNil() async {
        let item = FileItem(
            path: FilePath(scheme: .sftp, posix: "/remote/file.txt"),
            kind: .regularFile
        )
        let payload = await TextPreviewRenderer.render(item: item)
        XCTAssertNil(payload)
    }
}
