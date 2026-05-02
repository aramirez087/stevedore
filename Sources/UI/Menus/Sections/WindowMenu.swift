import SwiftUI

/// Window menu: New Tab, Close Tab, Reopen Closed Tab, Next/Previous Tab.
public struct WindowMenuCommands: Commands {
    @FocusedValue(\.paneCommandProxy) private var proxy

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .windowSize) {
            Divider()

            Button("New Tab") {
                proxy?.openNewTab()
            }
            .keyboardShortcut(Shortcuts.newTab)
            .disabled(proxy == nil)

            Button("Close Tab") {
                proxy?.closeActiveTab()
            }
            .keyboardShortcut(Shortcuts.closeTab)
            .disabled(proxy == nil)

            Button("Reopen Closed Tab") {
                proxy?.reopenClosedTab()
            }
            .keyboardShortcut(Shortcuts.reopenClosedTab)
            .disabled(proxy == nil)

            Divider()

            Button("Next Tab") {
                proxy?.nextTab()
            }
            .keyboardShortcut(Shortcuts.nextTab)
            .disabled(proxy == nil)

            Button("Previous Tab") {
                proxy?.previousTab()
            }
            .keyboardShortcut(Shortcuts.previousTab)
            .disabled(proxy == nil)
        }
    }
}
