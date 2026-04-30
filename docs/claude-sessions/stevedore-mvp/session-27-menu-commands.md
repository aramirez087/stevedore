---
session: 27
title: "Menu Commands & Keyboard Shortcuts"
depends_on: [10, 11, 12, 15, 21, 22, 23, 24, 25, 26]
touches:
  - Sources/UI/Menus/**
  - Tests/UITests/MenusTests/**
parallel_safe: false
---

# Session 27: Menu Commands & Keyboard Shortcuts

Paste this into a new Claude Code session:

```md
Continuity
Continue from Sessions 10, 11, 12, 15, 21, 22, 23, 24, 25, 26 artifacts. Read each handoff. Session 26 left `Sources/UI/Menus/AppCommands.swift` as a stub — fill it in here.

Mission
Wire every menu item and keyboard shortcut: File / Edit / View / Go / Connect / Tools / Window / Help. Surface dialogs (Connect, Sync, Multi-Rename, Uninstaller, Settings) and commands (New Folder, Trash, Show Hidden, Refresh, Open Terminal Here, etc.) bound to the active pane.

Repository anchors
- Sources/UI/Menus/AppCommands.swift (top-level CommandsBuilder)
- Sources/UI/Menus/Sections/FileMenu.swift
- Sources/UI/Menus/Sections/EditMenu.swift
- Sources/UI/Menus/Sections/ViewMenu.swift
- Sources/UI/Menus/Sections/GoMenu.swift
- Sources/UI/Menus/Sections/ConnectMenu.swift
- Sources/UI/Menus/Sections/ToolsMenu.swift
- Sources/UI/Menus/Sections/WindowMenu.swift
- Sources/UI/Menus/Shortcuts.swift (canonical shortcut registry)
- Sources/UI/Menus/OpenInTerminal.swift (NSWorkspace launch of Terminal/iTerm/Warp/Ghostty)
- Tests/UITests/MenusTests/*.swift

Tasks
1. `Shortcuts` declares every shortcut as a typed value — single source of truth so Settings UI can later show them and the menus can reference them.
2. **File**: New Folder (Cmd+Shift+N), New File (Cmd+N), Open (Cmd+O), Open With…, Move to Trash (Cmd+Delete), Compress, Decompress.
3. **Edit**: Cut, Copy, Paste, Select All, Find (Cmd+F → focuses the toolbar SearchField).
4. **View**: Show Hidden Files (Cmd+Shift+.), Refresh (Cmd+R), Sort By submenu, View As list/columns/icons.
5. **Go**: Up (Cmd+Up), Back (Cmd+[), Forward (Cmd+]), Home (Cmd+Shift+H), Computer, Recent Folders submenu.
6. **Connect**: Connect to Server… (Cmd+K) — opens Session 23 dialog. Recent Connections submenu.
7. **Tools**: Compare/Sync Folders (opens Session 21), Multi-Rename… (opens Session 22), Application Uninstaller… (opens Session 25), Open in Terminal (Cmd+Shift+T).
8. **Window**: New Tab (Cmd+T), Close Tab (Cmd+W), Reopen Closed Tab (Cmd+Shift+T conflict — prefer Cmd+Shift+Z), Next/Previous Tab.
9. Bind every command to the *active* pane via the environment object from Session 26. Disabled state where applicable (e.g., Trash disabled on remote read-only).
10. Tests: dispatch table coverage — every shortcut maps to exactly one command and invokes the expected callback in the active pane host. Use a recording fake `PaneSession` to assert.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-27-handoff.md` listing every command, its shortcut, and the action it dispatches; flagging any conflicts resolved.

Quality gates
- `swift build`
- `swift test --filter MenusTests`
- `swiftformat --lint Sources/UI/Menus Tests/UITests/MenusTests`
- `swiftlint --strict --path Sources/UI/Menus`
- `xcodebuild -scheme Stevedore -destination 'platform=macOS' build`

Exit criteria
- No two commands share a shortcut — verified by a unit test enumerating `Shortcuts`.
- Every menu item has either a disabled-when reason or a verified action.
- Open-in-Terminal honors the user's chosen terminal app from Settings.
```
