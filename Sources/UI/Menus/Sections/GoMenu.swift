import SwiftUI

/// Go menu: Up, Back, Forward, Home, Computer, Recent Folders.
public struct GoMenuCommands: Commands {
    @FocusedValue(\.paneCommandProxy) private var proxy

    public init() {}

    public var body: some Commands {
        CommandMenu("Go") {
            Button("Up") {
                proxy?.goUp()
            }
            .keyboardShortcut(Shortcuts.goUp)
            .disabled(proxy == nil)

            Button("Back") {
                proxy?.goBack()
            }
            .keyboardShortcut(Shortcuts.goBack)
            .disabled(proxy?.canGoBack != true)

            Button("Forward") {
                proxy?.goForward()
            }
            .keyboardShortcut(Shortcuts.goForward)
            .disabled(proxy?.canGoForward != true)

            Divider()

            Button("Home") {
                proxy?.goHome()
            }
            .keyboardShortcut(Shortcuts.goHome)
            .disabled(proxy == nil)

            Button("Computer") {
                proxy?.goToComputer()
            }
            .disabled(proxy == nil)

            Divider()

            Menu("Recent Folders") {
                Text("No Recent Folders")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
