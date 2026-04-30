import CoreGraphics
import Foundation

/// Quick Look-style preview generator.
///
/// Concrete sources will bridge to QLThumbnailGenerator, the Quick Look
/// preview panel, or a first-party renderer (text, hex, image). All return
/// raw `Data` to keep the protocol UI-agnostic.
public protocol PreviewSource: Sendable {
    func thumbnail(for item: FileItem, size: CGSize) async throws -> Data?
    func preview(for item: FileItem) async throws -> PreviewPayload?
}
