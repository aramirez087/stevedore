import SwiftUI

/// View menu: Show Hidden Files, Refresh, Sort By submenu, View As submenu.
public struct ViewMenuCommands: Commands {
    @FocusedValue(\.paneCommandProxy) private var proxy

    public init() {}

    public var body: some Commands {
        CommandMenu("View") {
            Button("Show Hidden Files") {
                self.proxy?.toggleHiddenFiles()
            }
            .keyboardShortcut(Shortcuts.showHiddenFiles)
            .disabled(self.proxy == nil)

            Button("Refresh") {
                self.proxy?.refresh()
            }
            .keyboardShortcut(Shortcuts.refresh)
            .disabled(self.proxy == nil)

            Divider()

            Menu("Sort By") {
                Button("Name") { self.proxy?.sortByName() }
                    .disabled(self.proxy == nil)
                Button("Date Modified") { self.proxy?.sortByDateModified() }
                    .disabled(self.proxy == nil)
                Button("Size") { self.proxy?.sortBySize() }
                    .disabled(self.proxy == nil)
                Button("Kind") { self.proxy?.sortByKind() }
                    .disabled(self.proxy == nil)
            }

            Divider()

            Button("as List") {}
                .disabled(true)
            Button("as Columns") {}
                .disabled(true)
            Button("as Icons") {}
                .disabled(true)
        }
    }
}
