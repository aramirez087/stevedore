import Core
import DesignSystem
import SwiftUI

// MARK: - Preview fakes (local to preview only)

private final class PreviewBookmarks: BookmarksProviding {
    var bookmarks: [Bookmark] = [
        Bookmark(displayName: "Home", path: FilePath(scheme: .local, posix: "/Users/demo")),
        Bookmark(displayName: "Projects", path: FilePath(scheme: .local, posix: "/Users/demo/Projects")),
    ]
    func add(_ bookmark: Bookmark) {
        self.bookmarks.append(bookmark)
    }

    func remove(id: Bookmark.ID) {
        self.bookmarks.removeAll { $0.id == id }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        self.bookmarks.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
}

private struct PreviewVolumes: VolumeDiscoveryProviding {
    func currentVolumes() async throws -> [SidebarVolume] {
        [
            SidebarVolume(url: URL(fileURLWithPath: "/"), name: "Macintosh HD", isEjectable: false, isRemovable: false),
            SidebarVolume(
                url: URL(fileURLWithPath: "/Volumes/USB"),
                name: "USB Drive",
                isEjectable: true,
                isRemovable: true
            ),
        ]
    }

    func volumeEvents() -> AsyncStream<SidebarVolumeEvent> {
        AsyncStream { _ in }
    }
}

private final class PreviewConnections: ConnectionStatusProviding {
    var descriptors: [RemoteHostDescriptor] = [
        RemoteHostDescriptor(displayName: "prod-server", scheme: .sftp, host: "192.168.1.1"),
        RemoteHostDescriptor(displayName: "s3-bucket", scheme: .s3, host: "s3.amazonaws.com"),
    ]
    func status(for id: RemoteHostDescriptor.ID) -> ConnectionStatus {
        id == self.descriptors.first?.id ? .connected : .idle
    }

    func add(_ descriptor: RemoteHostDescriptor) {
        self.descriptors.append(descriptor)
    }

    func remove(id: RemoteHostDescriptor.ID) {
        self.descriptors.removeAll { $0.id == id }
    }
}

private struct PreviewTags: TagsProviding {
    func fetchTags(forVolumeAt url: URL) async -> [String] {
        ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Grey"]
    }
}

private struct PreviewEjector: VolumeEjecting {
    func eject(volumeURL: URL) async throws {}
}

@MainActor
private func makePreviewViewModel() -> SidebarViewModel {
    SidebarViewModel(
        bookmarks: PreviewBookmarks(),
        volumeDiscovery: PreviewVolumes(),
        connectionStatus: PreviewConnections(),
        tagsProvider: PreviewTags(),
        ejector: PreviewEjector()
    )
}

// MARK: - Previews

#Preview("Light") {
    Sidebar(viewModel: makePreviewViewModel())
        .frame(width: 220, height: 600)
}

#Preview("Dark") {
    Sidebar(viewModel: makePreviewViewModel())
        .frame(width: 220, height: 600)
        .preferredColorScheme(.dark)
}
