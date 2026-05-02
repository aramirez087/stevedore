import Core
import SwiftUI

/// Editable list of user bookmarks; supports add-via-drop and remove/reorder via context menu.
struct FavoritesSection: View {
    @Bindable var viewModel: SidebarViewModel

    var body: some View {
        Section("Favorites") {
            ForEach(self.viewModel.bookmarks.bookmarks) { bookmark in
                SidebarRow(
                    title: bookmark.displayName,
                    symbolName: bookmark.symbolName ?? "folder"
                )
                .tag(SidebarItemID.bookmark(bookmark.id))
                .contextMenu {
                    Button("Remove") {
                        self.viewModel.bookmarks.remove(id: bookmark.id)
                    }
                }
            }
            .onMove { self.viewModel.bookmarks.move(fromOffsets: $0, toOffset: $1) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls {
                let path = FilePath(scheme: .local, posix: url.path)
                let bookmark = Bookmark(displayName: url.lastPathComponent, path: path)
                self.viewModel.bookmarks.add(bookmark)
            }
            return true
        }
    }
}
