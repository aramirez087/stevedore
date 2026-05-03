import SwiftUI
import UIMenus
import XCTest

final class ShortcutsTests: XCTestCase {
    private func encode(_ s: KeyboardShortcut) -> String {
        "\(s.key.character)\(s.modifiers.rawValue)"
    }

    func testAllShortcutsAreUnique() {
        let all: [KeyboardShortcut] = [
            Shortcuts.newFile,
            Shortcuts.newFolder,
            Shortcuts.open,
            Shortcuts.moveToTrash,
            Shortcuts.find,
            Shortcuts.showHiddenFiles,
            Shortcuts.refresh,
            Shortcuts.goUp,
            Shortcuts.goBack,
            Shortcuts.goForward,
            Shortcuts.goHome,
            Shortcuts.connectToServer,
            Shortcuts.openInTerminal,
            Shortcuts.newTab,
            Shortcuts.closeTab,
            Shortcuts.reopenClosedTab,
        ]
        var seen: Set<String> = []
        for shortcut in all {
            let key = self.encode(shortcut)
            XCTAssertTrue(
                seen.insert(key).inserted,
                "Duplicate shortcut: \(key)"
            )
        }
    }

    func testOpenInTerminalAndReopenClosedTabDoNotConflict() {
        XCTAssertNotEqual(
            self.encode(Shortcuts.openInTerminal),
            self.encode(Shortcuts.reopenClosedTab)
        )
    }

    func testNewTabAndOpenInTerminalDifferByModifiers() {
        XCTAssertNotEqual(
            self.encode(Shortcuts.newTab),
            self.encode(Shortcuts.openInTerminal)
        )
    }

    func testGoBackAndNextTabDoNotConflict() {
        // goBack = Cmd+[, nextTab = Cmd+Shift+]
        XCTAssertNotEqual(
            self.encode(Shortcuts.goBack),
            self.encode(Shortcuts.nextTab)
        )
    }

    func testGoForwardAndPreviousTabDoNotConflict() {
        // goForward = Cmd+], previousTab = Cmd+Shift+[
        XCTAssertNotEqual(
            self.encode(Shortcuts.goForward),
            self.encode(Shortcuts.previousTab)
        )
    }
}
