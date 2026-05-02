import Core
import Foundation

/// Uniquely identifies any selectable row in the sidebar.
public enum SidebarItemID: Hashable, Sendable {
    case bookmark(Bookmark.ID)
    case volume(URL)
    case connection(RemoteHostDescriptor.ID)
    case tag(String)
}
