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
}

extension WindowCommandProxy: @unchecked Sendable {}

extension FocusedValues {
    @Entry public var windowCommandProxy: WindowCommandProxy?
}
