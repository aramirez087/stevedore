import Foundation

/// Top-level UI state container: a window with two panes, each pane carrying
/// an ordered list of tabs and a selected tab.
public struct Workspace: Hashable, Sendable, Codable, Identifiable {
    public typealias ID = UUID

    public let id: ID
    public let leftPane: WorkspacePane
    public let rightPane: WorkspacePane

    public init(id: ID = UUID(), leftPane: WorkspacePane, rightPane: WorkspacePane) {
        self.id = id
        self.leftPane = leftPane
        self.rightPane = rightPane
    }
}

/// One half of a `Workspace`: a list of tabs plus the active tab's identifier.
public struct WorkspacePane: Hashable, Sendable, Codable, Identifiable {
    public typealias ID = UUID

    public let id: ID
    public let tabs: [Tab]
    public let activeTabID: Tab.ID?

    public init(id: ID = UUID(), tabs: [Tab], activeTabID: Tab.ID? = nil) {
        self.id = id
        self.tabs = tabs
        self.activeTabID = activeTabID
    }
}
