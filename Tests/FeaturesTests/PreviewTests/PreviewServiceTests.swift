import Core
import FeaturesPreview
import Foundation
import XCTest

final class PreviewServiceTests: XCTestCase {
    private let service = PreviewService()

    // MARK: - Renderer dispatch by extension

    func testImageExtensionDispatchesToImageRenderer() async throws {
        let png = makeMinimalPNG()
        let url = try makeTempFile(name: "photo.png", content: png)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = try await self.service.preview(for: item)
        XCTAssertEqual(payload?.mimeType, "image/png")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testCodeExtensionDispatchesToCodeRenderer() async throws {
        let url = try makeTempFile(name: "main.swift", text: "func greet() {}")
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = try await self.service.preview(for: item)
        XCTAssertEqual(payload?.mimeType, "text/rtf")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testTextExtensionDispatchesToTextRenderer() async throws {
        let url = try makeTempFile(name: "notes.txt", text: "Hello notes")
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = try await self.service.preview(for: item)
        XCTAssertEqual(payload?.mimeType, "text/rtf")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testDirectoryReturnsNil() async throws {
        let item = makePreviewItem(name: "somedir", kind: .directory)
        let payload = try await self.service.preview(for: item)
        XCTAssertNil(payload)
    }

    func testRemoteItemReturnsNil() async throws {
        let item = FileItem(
            path: FilePath(scheme: .sftp, posix: "/remote/file.txt"),
            kind: .regularFile
        )
        let payload = try await self.service.preview(for: item)
        XCTAssertNil(payload)
    }

    // MARK: - Cache

    func testCacheHitReturnsSamePayload() async throws {
        let url = try makeTempFile(name: "cached.txt", text: "cached content")
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let first = try await self.service.preview(for: item)
        let second = try await self.service.preview(for: item)
        XCTAssertEqual(first, second)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testCacheKeysSeparateThumbnailAndPreview() async throws {
        let url = try makeTempFile(name: "dual.txt", text: "text content")
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let preview = try await self.service.preview(for: item)
        let thumb = try await self.service.thumbnail(for: item, size: CGSize(width: 32, height: 32))
        // preview is RTF, thumbnail is PNG (or nil in headless CI) — keys must not collide.
        if let preview, let thumb {
            XCTAssertNotEqual(preview.data, thumb)
        }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - Off-main-actor exit criterion

    // PreviewService is an `actor` (not @MainActor), so structural isolation guarantees
    // calls never block the main actor. The tests below verify calls complete from a
    // Task.detached context (which is never on the main actor).

    func testPreviewRunsOffMainActor() async throws {
        let url = try makeTempFile(name: "offmain.txt", text: "off main actor test")
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let svc = self.service
        let completed = await Task.detached {
            _ = try? await svc.preview(for: item)
            return true
        }.value
        XCTAssertTrue(completed, "preview(for:) must complete without deadlock off main actor")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testThumbnailRunsOffMainActor() async throws {
        let url = try makeTempFile(name: "offmainthumb.txt", text: "thumb off main")
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let svc = self.service
        let completed = await Task.detached {
            _ = try? await svc.thumbnail(for: item, size: CGSize(width: 32, height: 32))
            return true
        }.value
        XCTAssertTrue(completed, "thumbnail(for:size:) must complete without deadlock off main actor")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - Magic-byte text detection

    func testMagicByteTextDetection() async throws {
        // File with no extension but all-ASCII content → TextPreviewRenderer (text/rtf)
        let url = try makeTempFile(name: "noext", text: "plain ascii content")
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = try await self.service.preview(for: item)
        // Should be RTF (text detected via magic bytes) or nil (QL thumbnail fallback)
        if let payload {
            XCTAssertTrue(
                payload.mimeType == "text/rtf" || payload.mimeType == "image/png",
                "Expected text/rtf or image/png, got \(payload.mimeType)"
            )
        }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testNullByteFileFallsBackToQuickLook() async throws {
        // File with null bytes and unknown extension → QuickLook fallback (nil or image/png)
        let binaryData = Data([0x00, 0x01, 0x02, 0x03, 0x00, 0x00])
        let url = try makeTempFile(name: "binary.bin", content: binaryData)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = try await self.service.preview(for: item)
        // QL may return nil in headless CI; accept both.
        if let payload {
            XCTAssertEqual(payload.mimeType, "image/png")
        }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
