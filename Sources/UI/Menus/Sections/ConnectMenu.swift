import SwiftUI

/// Connect menu: Connect to Server dialog (Cmd+K), Recent Connections submenu.
public struct ConnectMenuCommands: Commands {
    @FocusedValue(\.windowCommandProxy) private var windowProxy

    public init() {}

    public var body: some Commands {
        CommandMenu("Connect") {
            Button("Connect to Server\u{2026}") {
                windowProxy?.showConnectDialog()
            }
            .keyboardShortcut(Shortcuts.connectToServer)

            Divider()

            Menu("Recent Connections") {
                Text("No Recent Connections")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
