import Foundation

/// Local mirror of a mounted volume, keeping `UISidebar` independent of `FileSystemLocal`.
public struct SidebarVolume: Hashable, Sendable, Identifiable {
    public var id: URL {
        self.url
    }

    public let url: URL
    public let name: String
    public let isEjectable: Bool
    public let isRemovable: Bool

    public init(url: URL, name: String, isEjectable: Bool, isRemovable: Bool) {
        self.url = url
        self.name = name
        self.isEjectable = isEjectable
        self.isRemovable = isRemovable
    }
}

/// Change events delivered by `VolumeDiscoveryProviding.volumeEvents()`.
public enum SidebarVolumeEvent: Sendable {
    case mounted(SidebarVolume)
    case unmounted(URL)
}
