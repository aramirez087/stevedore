import Foundation

public struct AssociatedFile: Sendable, Identifiable {
    public let id: UUID
    public let url: URL
    public let sizeInBytes: Int64
    public let lastModified: Date
    public let confidence: Confidence
    public let reason: String
    public let requiresAdmin: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        sizeInBytes: Int64,
        lastModified: Date,
        confidence: Confidence,
        reason: String,
        requiresAdmin: Bool
    ) {
        self.id = id
        self.url = url
        self.sizeInBytes = sizeInBytes
        self.lastModified = lastModified
        self.confidence = confidence
        self.reason = reason
        self.requiresAdmin = requiresAdmin
    }
}
