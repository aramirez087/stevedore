import SwiftUI

/// Canonical keyboard shortcut registry for all Stevedore menu commands.
///
/// Single source of truth. The Settings UI can enumerate these for display,
/// and menus reference them by name rather than hard-coding raw values.
/// No two entries share the same key+modifier combination — verified by
/// `ShortcutsTests.testAllShortcutsAreUnique`.
public enum Shortcuts {
    // MARK: - File

    public static let newFile = KeyboardShortcut("n", modifiers: .command)
    public static let newFolder = KeyboardShortcut("n", modifiers: [.command, .shift])
    public static let open = KeyboardShortcut("o", modifiers: .command)
    /// Cmd+Delete (forward delete = \u{7F} on macOS keyboards labelled "Delete").
    public static let moveToTrash = KeyboardShortcut(KeyEquivalent("\u{7F}"), modifiers: .command)

    // MARK: - Edit

    public static let find = KeyboardShortcut("f", modifiers: .command)

    // MARK: - View

    public static let showHiddenFiles = KeyboardShortcut(".", modifiers: [.command, .shift])
    public static let refresh = KeyboardShortcut("r", modifiers: .command)

    // MARK: - Go

    public static let goUp = KeyboardShortcut(.upArrow, modifiers: .command)
    public static let goBack = KeyboardShortcut("[", modifiers: .command)
    public static let goForward = KeyboardShortcut("]", modifiers: .command)
    public static let goHome = KeyboardShortcut("h", modifiers: [.command, .shift])

    // MARK: - Connect

    public static let connectToServer = KeyboardShortcut("k", modifiers: .command)

    // MARK: - Tools

    public static let openInTerminal = KeyboardShortcut("t", modifiers: [.command, .shift])

    // MARK: - Window

    public static let newTab = KeyboardShortcut("t", modifiers: .command)
    public static let closeTab = KeyboardShortcut("w", modifiers: .command)
    /// Conflict with Tools/openInTerminal (both Cmd+Shift+T) resolved by using Cmd+Shift+Z.
    public static let reopenClosedTab = KeyboardShortcut("z", modifiers: [.command, .shift])
    public static let nextTab = KeyboardShortcut("]", modifiers: [.command, .shift])
    public static let previousTab = KeyboardShortcut("[", modifiers: [.command, .shift])
}
