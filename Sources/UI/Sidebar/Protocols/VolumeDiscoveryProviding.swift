import Foundation

/// Enumerates currently mounted volumes and streams mount/unmount events.
///
/// `Sendable` so it can be captured by the view model's background `Task`.
/// Session 26 provides `VolumeDiscoveryAdaptor` bridging `FileSystemLocal.VolumeDiscovery`.
public protocol VolumeDiscoveryProviding: Sendable {
    func currentVolumes() async throws -> [SidebarVolume]
    func volumeEvents() -> AsyncStream<SidebarVolumeEvent>
}
