import SwiftUI

/// Window-level command proxy injected via `FocusedValues`.
///
/// Carries actions that are not pane-specific: showing modal dialogs and
/// focusing the search field. `MainWindowView` constructs and injects this.
public struct WindowCommandProxy {
    public let showConnectDialog: () -> Void
    public let showSyncDialog: () -> Void
    public let showRenameDialog: () -> Void
    public let showUninstallerDialog: () -> Void
    /// Focuses the toolbar search field in the active pane.
    public let focusSearch: () -> Void

    public init(
        showConnectDialog: @escaping () -> Void,
        showSyncDialog: @escaping () -> Void,
        showRenameDialog: @escaping () -> Void,
        showUninstallerDialog: @escaping () -> Void,
        focusSearch: @escaping () -> Void
    ) {
        self.showConnectDialog = showConnectDialog
        self.showSyncDialog = showSyncDialog
        self.showRenameDialog = showRenameDialog
        self.showUninstallerDialog = showUninstallerDialog
        self.focusSearch = focusSearch
    }
}

extension WindowCommandProxy: @unchecked Sendable {}

public extension FocusedValues {
    @Entry var windowCommandProxy: WindowCommandProxy?
}
