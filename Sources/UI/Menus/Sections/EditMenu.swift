import SwiftUI

/// Edit menu: Find (Cmd+F focuses the toolbar search field).
/// Cut / Copy / Paste / Select All are system-provided and not replaced here.
public struct EditMenuCommands: Commands {
    @FocusedValue(\.windowCommandProxy) private var windowProxy

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Find\u{2026}") {
                windowProxy?.focusSearch()
            }
            .keyboardShortcut(Shortcuts.find)
        }
    }
}
