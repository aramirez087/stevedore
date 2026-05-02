import Core
import FeaturesOperations
import Foundation
@testable import MainWindow
import UISidebar
import XCTest

// MARK: - Factory helpers

@MainActor
func makeTestPaneSession(id: PaneID = .left) -> PaneSession {
    let home = FilePath(scheme: .local, posix: "/Users/test")
    return PaneSession(id: id, initialPath: home, provider: InMemoryFileSystemProvider())
}

func makeTestOperationQueue() -> FileOperationQueue {
    let executor = OperationExecutor(
        providers: [:],
        conflictResolver: ConflictResolver(),
        progressTracker: TransferProgressTracker()
    )
    return FileOperationQueue(executor: executor)
}

@MainActor
func makeTestMainWindowModel() -> MainWindowModel {
    let queue = makeTestOperationQueue()
    let sidebarVM = makeFakeSidebarViewModel()
    return MainWindowModel(
        operationQueue: queue,
        sidebarViewModel: sidebarVM,
        windowState: WindowState(),
        leftSession: makeTestPaneSession(id: .left),
        rightSession: makeTestPaneSession(id: .right),
        repository: nil
    )
}

// MARK: - Fake sidebar dependencies

// Prefixed MW to avoid collisions with SidebarTests fakes in the same UITests target.

@MainActor
func makeFakeSidebarViewModel() -> SidebarViewModel {
    SidebarViewModel(
        bookmarks: MWFakeBookmarksProvider(),
        volumeDiscovery: MWFakeVolumeDiscoveryProvider(),
        connectionStatus: MWFakeConnectionStatusProvider(),
        tagsProvider: MWFakeTagsProvider(),
        ejector: MWFakeVolumeEjector()
    )
}

@MainActor
final class MWFakeBookmarksProvider: BookmarksProviding {
    var bookmarks: [Bookmark] = []

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

final class MWFakeVolumeDiscoveryProvider: VolumeDiscoveryProviding, @unchecked Sendable {
    func currentVolumes() async throws -> [SidebarVolume] {
        []
    }

    func volumeEvents() -> AsyncStream<SidebarVolumeEvent> {
        AsyncStream { continuation in continuation.finish() }
    }
}

@MainActor
final class MWFakeConnectionStatusProvider: ConnectionStatusProviding {
    var descriptors: [RemoteHostDescriptor] = []

    func status(for id: RemoteHostDescriptor.ID) -> ConnectionStatus {
        .idle
    }

    func add(_ descriptor: RemoteHostDescriptor) {}
    func remove(id: RemoteHostDescriptor.ID) {}
}

struct MWFakeTagsProvider: TagsProviding {
    func fetchTags(forVolumeAt url: URL) async -> [String] {
        []
    }
}

struct MWFakeVolumeEjector: VolumeEjecting {
    func eject(volumeURL: URL) async throws {}
}
