import Core

/// Lists saved remote host descriptors and reports live connection status.
///
/// Isolated to `@MainActor` because `SidebarViewModel` reads it synchronously.
/// Session 26 wires in the production implementation backed by the connection engine.
@MainActor
public protocol ConnectionStatusProviding: AnyObject {
    var descriptors: [RemoteHostDescriptor] { get }
    func status(for id: RemoteHostDescriptor.ID) -> ConnectionStatus
    func add(_ descriptor: RemoteHostDescriptor)
    func remove(id: RemoteHostDescriptor.ID)
}
