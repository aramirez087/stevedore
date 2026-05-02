import SwiftUI

/// View menu: Show Hidden Files, Refresh, Sort By submenu, View As submenu.
public struct ViewMenuCommands: Commands {
    @FocusedValue(\.paneCommandProxy) private var proxy

    public init() {}

    public var body: some Commands {
        CommandMenu("View") {
            Button("Show Hidden Files") {
                proxy?.toggleHiddenFiles()
            }
            .keyboardShortcut(Shortcuts.showHiddenFiles)
            .disabled(proxy == nil)

            Button("Refresh") {
                proxy?.refresh()
            }
            .keyboardShortcut(Shortcuts.refresh)
            .disabled(proxy == nil)

            Divider()

            Menu("Sort By") {
                Button("Name") { proxy?.sortByName() }
                    .disabled(proxy == nil)
                Button("Date Modified") { proxy?.sortByDateModified() }
                    .disabled(proxy == nil)
                Button("Size") { proxy?.sortBySize() }
                    .disabled(proxy == nil)
                Button("Kind") { proxy?.sortByKind() }
                    .disabled(proxy == nil)
            }

            Divider()

            Button("as List") { }
                .disabled(true)
            Button("as Columns") { }
                .disabled(true)
            Button("as Icons") { }
                .disabled(true)
        }
    }
}
