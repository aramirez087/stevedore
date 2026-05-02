import SwiftUI

/// File menu: New File, New Folder, Open, Open With, Move to Trash, Compress, Decompress.
public struct FileMenuCommands: Commands {
    @FocusedValue(\.paneCommandProxy) private var proxy

    public init() {}

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New File") {
                proxy?.newFile()
            }
            .keyboardShortcut(Shortcuts.newFile)
            .disabled(proxy == nil)

            Button("New Folder") {
                proxy?.newFolder()
            }
            .keyboardShortcut(Shortcuts.newFolder)
            .disabled(proxy == nil)

            Divider()

            Button("Open") {
                proxy?.open()
            }
            .keyboardShortcut(Shortcuts.open)
            .disabled(proxy == nil)

            Button("Open With\u{2026}") {
                proxy?.openWith()
            }
            .disabled(proxy == nil)

            Divider()

            Button("Move to Trash") {
                proxy?.moveToTrash()
            }
            .keyboardShortcut(Shortcuts.moveToTrash)
            .disabled(proxy == nil || proxy?.isRemoteReadOnly == true)

            Divider()

            Button("Compress") {
                proxy?.compress()
            }
            .disabled(proxy == nil)

            Button("Decompress") {
                proxy?.decompress()
            }
            .disabled(proxy == nil)
        }
    }
}
