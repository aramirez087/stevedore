import SwiftUI

/// File menu: New File, New Folder, Open, Open With, Move to Trash, Compress, Decompress.
public struct FileMenuCommands: Commands {
    @FocusedValue(\.paneCommandProxy) private var proxy

    public init() {}

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New File") {
                self.proxy?.newFile()
            }
            .keyboardShortcut(Shortcuts.newFile)
            .disabled(self.proxy == nil)

            Button("New Folder") {
                self.proxy?.newFolder()
            }
            .keyboardShortcut(Shortcuts.newFolder)
            .disabled(self.proxy == nil)

            Divider()

            Button("Open") {
                self.proxy?.open()
            }
            .keyboardShortcut(Shortcuts.open)
            .disabled(self.proxy == nil)

            Button("Open With\u{2026}") {
                self.proxy?.openWith()
            }
            .disabled(self.proxy == nil)

            Divider()

            Button("Move to Trash") {
                self.proxy?.moveToTrash()
            }
            .keyboardShortcut(Shortcuts.moveToTrash)
            .disabled(self.proxy == nil || self.proxy?.isRemoteReadOnly == true)

            Divider()

            Button("Compress") {
                self.proxy?.compress()
            }
            .disabled(self.proxy == nil)

            Button("Decompress") {
                self.proxy?.decompress()
            }
            .disabled(self.proxy == nil)
        }
    }
}
