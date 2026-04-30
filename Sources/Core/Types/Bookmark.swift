import Foundation

/// A user-saved pointer to a `FilePath`, displayed in the sidebar.
public struct Bookmark: Hashable, Sendable, Codable, Identifiable {
    public typealias ID = UUID

    public let id: ID
    public let displayName: String
    public let path: FilePath
    public let symbolName: String?

    public init(id: ID = UUID(), displayName: String, path: FilePath, symbolName: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.symbolName = symbolName
    }
}
