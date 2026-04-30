import Foundation

/// Renderable preview content returned by `PreviewSource.preview(for:)`.
///
/// Quick Look-style sources may return image data; first-party renderers may
/// return text or HTML. The `mimeType` lets the consumer pick the right view.
public struct PreviewPayload: Hashable, Sendable {
    public let mimeType: String
    public let data: Data

    public init(mimeType: String, data: Data) {
        self.mimeType = mimeType
        self.data = data
    }
}
