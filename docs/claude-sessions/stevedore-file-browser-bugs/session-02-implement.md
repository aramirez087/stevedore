---
session: 2
title: "Implement: context menu + double-click navigation"
depends_on: [1]
touches:
  - Sources/UI/MainWindow/PaneHost.swift
  - Tests/UITests/MainWindowTests/MainWindowTests.swift
  - docs/roadmap/stevedore-file-browser-bugs/session-02-handoff.md
parallel_safe: false
model: "opus"
---

# Session 02: Implement Both Fixes

Paste this into a new Claude Code session:

```md
## Continuity
Continue from Session 01 artifacts.
Read `docs/roadmap/stevedore-file-browser-bugs/session-01-handoff.md` before writing any code.

## Mission
Fix bug-049 (missing right-click context menu) and bug-050 (single-tap folder navigation) in `FileBrowserView` inside `Sources/UI/MainWindow/PaneHost.swift`.

## Repository anchors
- `Sources/UI/MainWindow/PaneHost.swift` — the only file to modify (FileBrowserView is a private struct inside it)
- `Tests/UITests/MainWindowTests/MainWindowTests.swift` — add tests here
- `Tests/UITests/MainWindowTests/MainWindowTestSupport.swift` — test fakes (read-only)
- `docs/roadmap/stevedore-file-browser-bugs/session-01-handoff.md` — design plan (read first)

## Tasks

### Bug-049: Add right-click context menu
1. Add `.contextMenu` to the row HStack in FileBrowserView.
2. Include these menu items (use the Session 01 handoff for the exact list):
   - **Open** — navigate into directory; no-op for files (show disabled)
   - **Move to Trash** — call `session.provider` trash operation if available; otherwise show disabled
   - **Reveal in Finder** — `NSWorkspace.shared.activateFileViewerSelecting([url])`
3. Wire "Open" to `session.navigate(to: item.path)` for directories.
4. All placeholder items must be visually present but disabled, not omitted.

### Bug-050: Single-tap selects, double-tap navigates
5. Add `@State private var selectedItemPath: FilePath?` to FileBrowserView.
6. Replace the single `.onTapGesture` with two separate handlers:
   - `.onTapGesture(count: 2)` — navigate into directory or open file with `NSWorkspace`
   - `.onTapGesture(count: 1)` — set `selectedItemPath = item.path`
   Note: declare the double-tap handler BEFORE the single-tap handler so SwiftUI gives it priority.
7. Apply a selection highlight to the row: when `selectedItemPath == item.path`, use
   `theme.colors.accent.opacity(0.15)` as the row background.
8. Clear `selectedItemPath` when the path changes (use `.onChange(of: session.currentPath)`).

### Tests
9. Add tests to `MainWindowTests.swift` covering at minimum:
   - Single tap on a directory sets selection without navigating
   - Double tap on a directory navigates (currentPath changes)
   - Context menu is present on a directory row (use `inspect` or a rendered view smoke test)
   Use the existing MWFake* helpers from `MainWindowTestSupport.swift`.

## Quality gates
    swift build --target MainWindow -Xswiftc -warnings-as-errors 2>&1 | tail -10
    swift test --filter MainWindowTests 2>&1 | tail -20
    swiftformat Sources/UI/MainWindow Tests/UITests/MainWindowTests --lint 2>&1
    swiftlint --strict Sources/UI/MainWindow Tests/UITests/MainWindowTests 2>&1 | tail -10

## Exit criteria
- All four quality-gate commands exit 0.
- Right-clicking a row in FileBrowserView shows a context menu with at least Open, Move to Trash, Reveal in Finder.
- Single-clicking a directory selects it (no navigation). Double-clicking navigates.
- No regression in existing MainWindowTests.
```
