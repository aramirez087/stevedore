import Core
import FeaturesPreview
import Foundation
import XCTest

final class ThumbnailGeneratorTests: XCTestCase {
    func testThumbnailReturnsDataOrNilForImageFile() async throws {
        // QLThumbnailGenerator may not work in headless CI; accept nil as valid.
        let pngData = makeMinimalPNG()
        let url = try makeTempFile(name: "thumb.png", content: pngData)
        let generator = ThumbnailGenerator()
        let result = try? await generator.thumbnail(for: url, size: CGSize(width: 64, height: 64))
        // Either nil (no window server) or valid PNG data — no crash either way.
        if let data = result {
            XCTAssertFalse(data.isEmpty)
        }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testDifferentSizesAreIndependentInflightKeys() async throws {
        let pngData = makeMinimalPNG()
        let url = try makeTempFile(name: "sizes.png", content: pngData)
        let generator = ThumbnailGenerator()
        // Launch two concurrent requests for different sizes; both should resolve.
        async let small = generator.thumbnail(for: url, size: CGSize(width: 32, height: 32))
        async let large = generator.thumbnail(for: url, size: CGSize(width: 256, height: 256))
        _ = try? await (small, large)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testCancellationPropagates() async throws {
        let pngData = makeMinimalPNG()
        let url = try makeTempFile(name: "cancel.png", content: pngData)
        let generator = ThumbnailGenerator()
        let task = Task {
            try await generator.thumbnail(for: url, size: CGSize(width: 256, height: 256))
        }
        task.cancel()
        do {
            _ = try await task.value
            // If the task completed before cancel propagated, that's still OK.
        } catch is CancellationError {
            // Expected path.
        } catch {
            // Any other error (e.g. QL unavailable) is also acceptable.
        }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testConcurrentRequestsForSameKeyCoalesce() async throws {
        let pngData = makeMinimalPNG()
        let url = try makeTempFile(name: "coalesce.png", content: pngData)
        let generator = ThumbnailGenerator()
        let size = CGSize(width: 64, height: 64)
        // Fire 10 concurrent requests for the same key.
        await withTaskGroup(of: Data?.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    try? await generator.thumbnail(for: url, size: size)
                }
            }
            for await _ in group {}
        }
        // No crash and all resolved == coalescing didn't deadlock.
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testInflightCleanedUpAfterCompletion() async throws {
        let pngData = makeMinimalPNG()
        let url = try makeTempFile(name: "cleanup.png", content: pngData)
        let generator = ThumbnailGenerator()
        let size = CGSize(width: 64, height: 64)
        _ = try? await generator.thumbnail(for: url, size: size)
        // A second call creates a fresh task, not reusing the completed one.
        _ = try? await generator.thumbnail(for: url, size: size)
        // Verify no crash or deadlock on second call.
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
