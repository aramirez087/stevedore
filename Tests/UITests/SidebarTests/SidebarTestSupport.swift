import Core
import Foundation
import os
@testable import UISidebar
import XCTest

// MARK: - FakeBookmarksProvider

@MainActor
final class FakeBookmarksProvider: BookmarksProviding {
    var bookmarks: [Bookmark]
    private(set) var addCalls: [Bookmark] = []
    private(set) var removeCalls: [Bookmark.ID] = []
    private(set) var moveCalls: [(IndexSet, Int)] = []

    init(bookmarks: [Bookmark] = []) {
        self.bookmarks = bookmarks
    }

    func add(_ bookmark: Bookmark) {
        self.addCalls.append(bookmark)
        self.bookmarks.append(bookmark)
    }

    func remove(id: Bookmark.ID) {
        self.removeCalls.append(id)
        self.bookmarks.removeAll { $0.id == id }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        self.moveCalls.append((fromOffsets, toOffset))
        self.bookmarks.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
}

// MARK: - FakeVolumeDiscovery

final actor FakeVolumeDiscovery: VolumeDiscoveryProviding {
    private nonisolated let _volumes: [SidebarVolume]
    nonisolated let eventStream: AsyncStream<SidebarVolumeEvent>
    private nonisolated let continuation: AsyncStream<SidebarVolumeEvent>.Continuation

    init(volumes: [SidebarVolume] = []) {
        self._volumes = volumes
        (self.eventStream, self.continuation) = AsyncStream<SidebarVolumeEvent>.makeStream()
    }

    nonisolated func currentVolumes() async throws -> [SidebarVolume] {
        self._volumes
    }

    nonisolated func volumeEvents() -> AsyncStream<SidebarVolumeEvent> {
        self.eventStream
    }

    nonisolated func emit(_ event: SidebarVolumeEvent) {
        self.continuation.yield(event)
    }
}

// MARK: - FakeConnectionStatus

@MainActor
final class FakeConnectionStatus: ConnectionStatusProviding {
    var descriptors: [RemoteHostDescriptor]
    var statusMap: [RemoteHostDescriptor.ID: ConnectionStatus] = [:]
    private(set) var addCalls: [RemoteHostDescriptor] = []
    private(set) var removeCalls: [RemoteHostDescriptor.ID] = []

    init(descriptors: [RemoteHostDescriptor] = []) {
        self.descriptors = descriptors
    }

    func status(for id: RemoteHostDescriptor.ID) -> ConnectionStatus {
        self.statusMap[id] ?? .idle
    }

    func add(_ descriptor: RemoteHostDescriptor) {
        self.addCalls.append(descriptor)
        self.descriptors.append(descriptor)
    }

    func remove(id: RemoteHostDescriptor.ID) {
        self.removeCalls.append(id)
        self.descriptors.removeAll { $0.id == id }
    }
}

// MARK: - FakeTagsProvider

struct FakeTagsProvider: TagsProviding, @unchecked Sendable {
    let tags: [String]
    init(tags: [String] = []) {
        self.tags = tags
    }

    func fetchTags(forVolumeAt url: URL) async -> [String] {
        self.tags
    }
}

// MARK: - FakeVolumeEjector

final class FakeVolumeEjector: VolumeEjecting, @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<[URL]>(initialState: [])
    var ejectCalls: [URL] {
        self.lock.withLock { $0 }
    }

    var shouldThrow = false

    func eject(volumeURL: URL) async throws {
        self.lock.withLock { $0.append(volumeURL) }
        if self.shouldThrow {
            throw StevedoreError.fileSystem(.ioFailure(detail: "eject failed"))
        }
    }
}

// MARK: - Factory

@MainActor
func makeSidebarViewModel(
    bookmarks: FakeBookmarksProvider = FakeBookmarksProvider(),
    volumes: FakeVolumeDiscovery = FakeVolumeDiscovery(),
    connections: FakeConnectionStatus = FakeConnectionStatus(),
    tags: FakeTagsProvider = FakeTagsProvider(),
    ejector: FakeVolumeEjector = FakeVolumeEjector()
) -> SidebarViewModel {
    SidebarViewModel(
        bookmarks: bookmarks,
        volumeDiscovery: volumes,
        connectionStatus: connections,
        tagsProvider: tags,
        ejector: ejector
    )
}

// MARK: - Helpers

extension SidebarVolume {
    static func fake(
        path: String = "/Volumes/Fake",
        name: String = "Fake",
        isEjectable: Bool = false,
        isRemovable: Bool = false
    ) -> SidebarVolume {
        SidebarVolume(
            url: URL(fileURLWithPath: path),
            name: name,
            isEjectable: isEjectable,
            isRemovable: isRemovable
        )
    }
}

extension Bookmark {
    static func fake(name: String = "Fake", path: String = "/tmp") -> Bookmark {
        Bookmark(
            displayName: name,
            path: FilePath(scheme: .local, posix: path)
        )
    }
}

extension RemoteHostDescriptor {
    static func fake(name: String = "host", scheme: ConnectionScheme = .sftp) -> RemoteHostDescriptor {
        RemoteHostDescriptor(displayName: name, scheme: scheme, host: "192.168.1.1")
    }
}
