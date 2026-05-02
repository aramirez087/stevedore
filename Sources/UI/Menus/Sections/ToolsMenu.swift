import SwiftUI

/// Tools menu: Compare/Sync, Multi-Rename, Application Uninstaller, Open in Terminal.
public struct ToolsMenuCommands: Commands {
    @FocusedValue(\.paneCommandProxy) private var proxy
    @FocusedValue(\.windowCommandProxy) private var windowProxy

    public init() {}

    public var body: some Commands {
        CommandMenu("Tools") {
            Button("Compare/Sync Folders\u{2026}") {
                windowProxy?.showSyncDialog()
            }

            Button("Multi-Rename\u{2026}") {
                windowProxy?.showRenameDialog()
            }

            Button("Application Uninstaller\u{2026}") {
                windowProxy?.showUninstallerDialog()
            }

            Divider()

            Button("Open in Terminal") {
                proxy?.openInTerminal()
            }
            .keyboardShortcut(Shortcuts.openInTerminal)
            .disabled(proxy == nil)
        }
    }
}
