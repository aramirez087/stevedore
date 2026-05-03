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

    public init(
        currentPath: FilePath,
        canGoBack: Bool,
        canGoForward: Bool,
        isRemoteReadOnly: Bool,
        goBack: @escaping () -> Void,
        goForward: @escaping () -> Void,
        goUp: @escaping () -> Void,
        goHome: @escaping () -> Void,
        goToComputer: @escaping () -> Void,
        newFolder: @escaping () -> Void,
        newFile: @escaping () -> Void,
        open: @escaping () -> Void,
        openWith: @escaping () -> Void,
        moveToTrash: @escaping () -> Void,
        compress: @escaping () -> Void,
        decompress: @escaping () -> Void,
        toggleHiddenFiles: @escaping () -> Void,
        refresh: @escaping () -> Void,
        openInTerminal: @escaping () -> Void,
        openNewTab: @escaping () -> Void,
        closeActiveTab: @escaping () -> Void,
        reopenClosedTab: @escaping () -> Void,
        nextTab: @escaping () -> Void,
        previousTab: @escaping () -> Void,
        selectAll: @escaping () -> Void,
        sortByName: @escaping () -> Void,
        sortByDateModified: @escaping () -> Void,
        sortBySize: @escaping () -> Void,
        sortByKind: @escaping () -> Void
    ) {
        self.currentPath = currentPath
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isRemoteReadOnly = isRemoteReadOnly
        self.goBack = goBack
        self.goForward = goForward
        self.goUp = goUp
        self.goHome = goHome
        self.goToComputer = goToComputer
        self.newFolder = newFolder
        self.newFile = newFile
        self.open = open
        self.openWith = openWith
        self.moveToTrash = moveToTrash
        self.compress = compress
        self.decompress = decompress
        self.toggleHiddenFiles = toggleHiddenFiles
        self.refresh = refresh
        self.openInTerminal = openInTerminal
        self.openNewTab = openNewTab
        self.closeActiveTab = closeActiveTab
        self.reopenClosedTab = reopenClosedTab
        self.nextTab = nextTab
        self.previousTab = previousTab
        self.selectAll = selectAll
        self.sortByName = sortByName
        self.sortByDateModified = sortByDateModified
        self.sortBySize = sortBySize
        self.sortByKind = sortByKind
    }
}

/// Closures are always constructed and invoked on the main thread (SwiftUI guarantees this
/// for Commands body evaluation and button action dispatch).
extension PaneCommandProxy: @unchecked Sendable {}

public extension FocusedValues {
    @Entry var paneCommandProxy: PaneCommandProxy?
}
