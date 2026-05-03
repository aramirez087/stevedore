import SwiftUI

/// Window menu: New Tab, Close Tab, Reopen Closed Tab, Next/Previous Tab.
public struct WindowMenuCommands: Commands {
    @FocusedValue(\.paneCommandProxy) private var proxy

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .windowSize) {
            Divider()

            Button("New Tab") {
                self.proxy?.openNewTab()
            }
            .keyboardShortcut(Shortcuts.newTab)
            .disabled(self.proxy == nil)

            Button("Close Tab") {
                self.proxy?.closeActiveTab()
            }
            .keyboardShortcut(Shortcuts.closeTab)
            .disabled(self.proxy == nil)

            Button("Reopen Closed Tab") {
                self.proxy?.reopenClosedTab()
            }
            .keyboardShortcut(Shortcuts.reopenClosedTab)
            .disabled(self.proxy == nil)

            Divider()

            Button("Next Tab") {
                self.proxy?.nextTab()
            }
            .keyboardShortcut(Shortcuts.nextTab)
            .disabled(self.proxy == nil)

            Button("Previous Tab") {
                self.proxy?.previousTab()
            }
            .keyboardShortcut(Shortcuts.previousTab)
            .disabled(self.proxy == nil)
        }
    }
}
