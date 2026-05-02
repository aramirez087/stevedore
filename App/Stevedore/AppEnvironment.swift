import AppKit
import Core
import FeaturesOperations
import FileSystemLocal
import Foundation
import MainWindow
import Observation
import ServicesSettings
import UISidebar

/// Dependency-injection root: constructs every concrete service once and assembles
/// `MainWindowModel`. Owned by `StevedoreApp` via `@State`, so it is created once
/// and lives for the application lifetime.
@MainActor
@Observable
final class AppEnvironment {
    let mainWindowModel: MainWindowModel

    // Strong references prevent premature release of actors.
    @ObservationIgnored private let localProvider: LocalFileSystemProvider
    @ObservationIgnored private let operationQueue: FileOperationQueue
    @ObservationIgnored private let workspacesRepository: WorkspacesRepository?
    @ObservationIgnored private let bookmarksRepository: BookmarksRepository?

    init() {
        localProvider = LocalFileSystemProvider()

        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stevedore")

        workspacesRepository = try? {
            let store = try JSONFileStore(directory: appSupport, filename: "workspaces")
            return WorkspacesRepository(store: store)
        }()

        bookmarksRepository = try? {
            let store = try JSONFileStore(directory: appSupport, filename: "bookmarks")
            return BookmarksRepository(store: store)
        }()

        let executor = OperationExecutor(
            providers: [ConnectionScheme.local: localProvider],
            conflictResolver: ConflictResolver(),
            progressTracker: TransferProgressTracker()
        )
        operationQueue = FileOperationQueue(executor: executor)

        let home = FilePath(scheme: .local, posix: NSHomeDirectory())
        let leftSession = PaneSession(id: .left, initialPath: home, provider: localProvider)
        let rightSession = PaneSession(id: .right, initialPath: home, provider: localProvider)

        let bookmarksAdapter = BookmarksProviderAdapter(repository: bookmarksRepository)
        let discovery = VolumeDiscovery()
        let volumeAdapter = VolumeDiscoveryAdaptor(discovery: discovery)

        let sidebarVM = SidebarViewModel(
            bookmarks: bookmarksAdapter,
            volumeDiscovery: volumeAdapter,
            connectionStatus: StubConnectionStatusProvider(),
            tagsProvider: FileLabelsProvider(),
            ejector: SystemVolumeEjector()
        )

        mainWindowModel = MainWindowModel(
            operationQueue: operationQueue,
            sidebarViewModel: sidebarVM,
            windowState: WindowState(),
            leftSession: leftSession,
            rightSession: rightSession,
            repository: workspacesRepository
        )
    }
}

// MARK: - Private concrete adapter types

/// Bridges `BookmarksRepository` (actor) to the synchronous `@MainActor` `BookmarksProviding` protocol.
/// Uses optimistic in-memory mutation with async persistence.
@MainActor
private final class BookmarksProviderAdapter: BookmarksProviding {
    var bookmarks: [Bookmark] = []
    private let repository: BookmarksRepository?

    init(repository: BookmarksRepository?) {
        self.repository = repository
        Task { @MainActor [weak self] in
            guard let self, let repo = repository else { return }
            self.bookmarks = await repo.all()
        }
    }

    func add(_ bookmark: Bookmark) {
        bookmarks.append(bookmark)
        persist()
    }

    func remove(id: Bookmark.ID) {
        bookmarks.removeAll { $0.id == id }
        persist()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        bookmarks.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    private func persist() {
        guard let repo = repository else { return }
        let snapshot = bookmarks
        Task { try? await repo.save(snapshot) }
    }
}

/// Bridges `FileSystemLocal.VolumeDiscovery` actor to `VolumeDiscoveryProviding`.
private struct VolumeDiscoveryAdaptor: VolumeDiscoveryProviding {
    private let discovery: VolumeDiscovery

    init(discovery: VolumeDiscovery) {
        self.discovery = discovery
    }

    func currentVolumes() async throws -> [SidebarVolume] {
        try await discovery.currentVolumes().map { vol in
            SidebarVolume(
                url: vol.url,
                name: vol.name,
                isEjectable: vol.isEjectable,
                isRemovable: vol.isRemovable
            )
        }
    }

    func volumeEvents() -> AsyncStream<SidebarVolumeEvent> {
        let raw = discovery.events()
        return AsyncStream { continuation in
            let task = Task {
                for await event in raw {
                    switch event {
                    case .mounted(let vol):
                        let sidebar = SidebarVolume(
                            url: vol.url,
                            name: vol.name,
                            isEjectable: vol.isEjectable,
                            isRemovable: vol.isRemovable
                        )
                        continuation.yield(.mounted(sidebar))
                    case .unmounted(let url):
                        continuation.yield(.unmounted(url))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Returns `[]` descriptors and `.idle` status.
/// Full implementation is a future session (remote connection engine).
@MainActor
private final class StubConnectionStatusProvider: ConnectionStatusProviding {
    var descriptors: [RemoteHostDescriptor] = []

    func status(for id: RemoteHostDescriptor.ID) -> ConnectionStatus {
        .idle
    }

    func add(_ descriptor: RemoteHostDescriptor) {}

    func remove(id: RemoteHostDescriptor.ID) {}
}

/// Returns Finder tag names via `NSWorkspace.shared.fileLabels`.
private struct FileLabelsProvider: TagsProviding {
    func fetchTags(forVolumeAt url: URL) async -> [String] {
        await MainActor.run { NSWorkspace.shared.fileLabels }
    }
}
