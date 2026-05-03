import Core
import Foundation
import SwiftUI

/// Drives the sidebar: holds observable state and routes mutations to injected providers.
///
/// All five dependencies are injected via the initializer — no global lookups.
/// Session 26 creates the production instance with concrete implementations.
@MainActor
@Observable
public final class SidebarViewModel {
    // MARK: - Observable state (drives UI re-renders)

    public private(set) var selection: SidebarItemID?
    public private(set) var volumes: [SidebarVolume] = []
    public private(set) var tags: [String] = []

    // MARK: - Injected dependencies (not observed — they are providers, not state)

    @ObservationIgnored public let bookmarks: any BookmarksProviding
    @ObservationIgnored public let connectionStatus: any ConnectionStatusProviding
    @ObservationIgnored public let ejector: any VolumeEjecting
    @ObservationIgnored private let volumeDiscovery: any VolumeDiscoveryProviding
    @ObservationIgnored private let tagsProvider: any TagsProviding

    @ObservationIgnored private var volumeTask: Task<Void, Never>?

    public init(
        bookmarks: some BookmarksProviding,
        volumeDiscovery: some VolumeDiscoveryProviding,
        connectionStatus: some ConnectionStatusProviding,
        tagsProvider: some TagsProviding,
        ejector: some VolumeEjecting
    ) {
        self.bookmarks = bookmarks
        self.volumeDiscovery = volumeDiscovery
        self.connectionStatus = connectionStatus
        self.tagsProvider = tagsProvider
        self.ejector = ejector
    }

    // MARK: - Selection

    public func select(_ id: SidebarItemID?) {
        self.selection = id
    }

    // MARK: - Lifecycle

    /// Loads initial volumes and tags, then subscribes to volume-change events.
    /// Idempotent: subsequent calls are no-ops while the task is live.
    func start() async {
        guard self.volumeTask == nil else { return }

        if let raw = try? await volumeDiscovery.currentVolumes() {
            self.volumes = Self.normalizeVolumes(raw)
        }
        if let firstURL = volumes.first?.url {
            self.tags = await self.tagsProvider.fetchTags(forVolumeAt: firstURL)
        }

        // Capture the Sendable provider so the task closure does not hold self strongly.
        let discovery = self.volumeDiscovery
        self.volumeTask = Task { [weak self] in
            for await event in discovery.volumeEvents() {
                guard let self else { break }
                switch event {
                case .mounted(let vol):
                    guard !Self.isAutofsHome(vol.url) else { break }
                    if !self.volumes.contains(where: { $0.url == vol.url }) {
                        self.volumes.append(vol)
                    }
                case .unmounted(let url):
                    self.volumes.removeAll { $0.url == url }
                }
            }
        }
    }

    // MARK: - Volume eject

    func ejectVolume(url: URL) async {
        try? await self.ejector.eject(volumeURL: url)
    }

    deinit {
        volumeTask?.cancel()
    }

    // MARK: - Private helpers

    /// Returns true for the macOS autofs /home firmlink — never the user's real home.
    private static func isAutofsHome(_ url: URL) -> Bool {
        url.path == "/System/Volumes/Data/home" || url.path == "/home"
    }

    // Strips the autofs entry and prepends a synthetic Home volume.
    // TODO(orchestrator): consider moving filter to VolumeDiscoveryAdaptor
    private static func normalizeVolumes(_ raw: [SidebarVolume]) -> [SidebarVolume] {
        let home = SidebarVolume(
            url: FileManager.default.homeDirectoryForCurrentUser,
            name: "Home",
            isEjectable: false,
            isRemovable: false
        )
        return [home] + raw.filter { !Self.isAutofsHome($0.url) }
    }
}
