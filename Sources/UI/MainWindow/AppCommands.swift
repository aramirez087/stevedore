import SwiftUI
import UIMenus

/// Top-level `Commands` that compose all seven menu-bar sections.
///
/// Injected via `.commands { AppCommands() }` in `MainWindowScene`.
/// Each section struct reads the active pane and window proxies from
/// `FocusedValues` and dispatches to them independently.
public struct AppCommands: Commands {
    public init() {}

    public var body: some Commands {
        FileMenuCommands()
        EditMenuCommands()
        ViewMenuCommands()
        GoMenuCommands()
        ConnectMenuCommands()
        ToolsMenuCommands()
        WindowMenuCommands()
    }
}
