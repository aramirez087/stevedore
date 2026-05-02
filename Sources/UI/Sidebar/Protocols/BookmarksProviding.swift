import Core
import Foundation

/// Provides and mutates the user's saved bookmark list.
///
/// Isolated to `@MainActor` because `SidebarViewModel` reads and mutates it synchronously.
/// The Settings session (24) provides the production implementation.
@MainActor
public protocol BookmarksProviding: AnyObject {
    var bookmarks: [Bookmark] { get }
    func add(_ bookmark: Bookmark)
    func remove(id: Bookmark.ID)
    func move(fromOffsets: IndexSet, toOffset: Int)
}
