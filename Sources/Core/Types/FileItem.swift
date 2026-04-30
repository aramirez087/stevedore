/// A directory listing entry.
///
/// `FileItem` is the primary value flowing across module boundaries: providers
/// produce it, the operation engine consumes it, the UI binds to it. Hashable
/// so SwiftUI's diffable lists can use it as an `id`.
public struct FileItem: Hashable, Sendable, Codable {
    public let path: FilePath
    public let kind: FileKind
    public let attributes: FileAttributes

    public init(path: FilePath, kind: FileKind, attributes: FileAttributes = .empty) {
        self.path = path
        self.kind = kind
        self.attributes = attributes
    }

    /// Convenience: the item's display name.
    public var displayName: String {
        self.path.lastComponent ?? "/"
    }
}
