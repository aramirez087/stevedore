import Foundation

/// One pane's view state inside a workspace.
public struct Tab: Hashable, Sendable, Codable, Identifiable {
    public typealias ID = UUID

    public let id: ID
    public let path: FilePath
    public let title: String?

    public init(id: ID = UUID(), path: FilePath, title: String? = nil) {
        self.id = id
        self.path = path
        self.title = title
    }
}
