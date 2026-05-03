import SwiftUI

/// Go menu: Up, Back, Forward, Home, Computer, Recent Folders.
public struct GoMenuCommands: Commands {
    @FocusedValue(\.paneCommandProxy) private var proxy

    public init() {}

    public var body: some Commands {
        CommandMenu("Go") {
            Button("Up") {
                self.proxy?.goUp()
            }
            .keyboardShortcut(Shortcuts.goUp)
            .disabled(self.proxy == nil)

            Button("Back") {
                self.proxy?.goBack()
            }
            .keyboardShortcut(Shortcuts.goBack)
            .disabled(self.proxy?.canGoBack != true)

            Button("Forward") {
                self.proxy?.goForward()
            }
            .keyboardShortcut(Shortcuts.goForward)
            .disabled(self.proxy?.canGoForward != true)

            Divider()

            Button("Home") {
                self.proxy?.goHome()
            }
            .keyboardShortcut(Shortcuts.goHome)
            .disabled(self.proxy == nil)

            Button("Computer") {
                self.proxy?.goToComputer()
            }
            .disabled(self.proxy == nil)

            Divider()

            Menu("Recent Folders") {
                Text("No Recent Folders")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
