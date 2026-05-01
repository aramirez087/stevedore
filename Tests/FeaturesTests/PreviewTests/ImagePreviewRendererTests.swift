import AppKit
import Core
@testable import FeaturesPreview
import Foundation
import XCTest

final class ImagePreviewRendererTests: XCTestCase {
    func testPngFileDecodesSuccessfully() async throws {
        let pngData = makeMinimalPNG()
        let url = try makeTempFile(name: "test.png", content: pngData)
        let item = FileItem(path: FilePath(scheme: .local, posix: url.path), kind: .regularFile)
        let payload = await ImagePreviewRenderer.render(item: item)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.mimeType, "image/png")
        XCTAssertFalse(payload?.data.isEmpty ?? true)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testNonExistentFileReturnsNil() async {
        let item = FileItem(
            path: FilePath(scheme: .local, posix: "/nonexistent/path/image.png"),
            kind: .regularFile
        )
        let payload = await ImagePreviewRenderer.render(item: item)
        XCTAssertNil(payload)
    }

    func testSmallImageNotUpscaled() {
        let smallImage = NSImage(size: NSSize(width: 50, height: 50))
        let resampled = ImagePreviewRenderer.resample(smallImage, maxDimension: 1024)
        XCTAssertEqual(resampled.size.width, 50)
        XCTAssertEqual(resampled.size.height, 50)
    }

    func testLargeImageResampled() {
        // Build a 2000×2000 image; after resampling with maxDimension=1024, dims ≤ 1024.
        let large = NSImage(size: NSSize(width: 2000, height: 2000))
        let resampled = ImagePreviewRenderer.resample(large, maxDimension: 1024)
        XCTAssertLessThanOrEqual(resampled.size.width, 1024)
        XCTAssertLessThanOrEqual(resampled.size.height, 1024)
    }

    func testNonLocalReturnsNil() async {
        let item = FileItem(
            path: FilePath(scheme: .sftp, posix: "/remote/file.png"),
            kind: .regularFile
        )
        let payload = await ImagePreviewRenderer.render(item: item)
        XCTAssertNil(payload)
    }

    func testDirectoryReturnsNil() async {
        let item = makePreviewItem(name: "images", kind: .directory)
        let payload = await ImagePreviewRenderer.render(item: item)
        XCTAssertNil(payload)
    }
}
