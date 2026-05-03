import AppKit
import Core
import Foundation
import QuickLookThumbnailing

public actor ThumbnailGenerator {
    /// In-flight tasks keyed by "path:WxH" — coalesces concurrent requests for the same key.
    private var inflight: [String: Task<Data?, any Error>] = [:]

    public init() {}

    public func thumbnail(for url: URL, size: CGSize) async throws -> Data? {
        let key = Self.inflightKey(url, size)
        if let existing = self.inflight[key] {
            return try await existing.value
        }
        let task = Task<Data?, any Error> {
            try await Self.generate(url: url, size: size)
        }
        self.inflight[key] = task
        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            self.inflight.removeValue(forKey: key)
            return result
        } catch {
            self.inflight.removeValue(forKey: key)
            throw error
        }
    }

    private static func inflightKey(_ url: URL, _ size: CGSize) -> String {
        "\(url.path):\(Int(size.width))x\(Int(size.height))"
    }

    private static func generate(url: URL, size: CGSize) async throws -> Data? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 1.0,
            representationTypes: .thumbnail
        )
        return try await withCheckedThrowingContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let cgImage = rep?.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                let png = bitmapRep.representation(using: .png, properties: [:])
                continuation.resume(returning: png)
            }
        }
    }
}
