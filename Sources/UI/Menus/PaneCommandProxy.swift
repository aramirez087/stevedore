import Core
import SwiftUI

/// Per-pane command proxy injected via `FocusedValues` so menu-bar Commands can
/// dispatch to whichever pane currently holds keyboard focus.
///
/// Closures are plain `() -> Void` because SwiftUI button actions always execute
/// on the main thread. `PaneHost` creates a fresh proxy on every render cycle so
/// `canGoBack` / `canGoForward` / `isRemoteReadOnly` reflect current state.
public struct PaneCommandProxy {
    // MARK: - Observed state (drives disabled conditions)

    public let currentPath: FilePath
    public let canGoBack: Bool
    public let canGoForward: Bool
    /// `true` when the active pane is on a read-only remote provider (disables Trash).
    public let isRemoteReadOnly: Bool

    // MARK: - Navigation

    public let goBack: () -> Void
    public let goForward: () -> Void
    public let goUp: () -> Void
    public let goHome: () -> Void
    public let goToComputer: () -> Void

    // MARK: - File operations

    public let newFolder: () -> Void
    public let newFile: () -> Void
    public let open: () -> Void
    public let openWith: () -> Void
    public let moveToTrash: () -> Void
    public let compress: () -> Void
    public let decompress: () -> Void
    public let toggleHiddenFiles: () -> Void
    public let refresh: () -> Void
    public let openInTerminal: () -> Void

    // MARK: - Tab management

    public let openNewTab: () -> Void
    public let closeActiveTab: () -> Void
    public let reopenClosedTab: () -> Void
    public let nextTab: () -> Void
    public let previousTab: () -> Void

    // MARK: - Edit

    public let selectAll: () -> Void

    // MARK: - Sort

    public let sortByName: () -> Void
    public let sortByDateModified: () -> Void
    public let sortBySize: () -> Void
    public let sortByKind: () -> Void
}

// Closures are always constructed and invoked on the main thread (SwiftUI guarantees this
// for Commands body evaluation and button action dispatch).
extension PaneCommandProxy: @unchecked Sendable {}

extension FocusedValues {
    @Entry public var paneCommandProxy: PaneCommandProxy?
}
