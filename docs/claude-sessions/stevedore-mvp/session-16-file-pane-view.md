---
session: 16
title: "File Pane View"
depends_on: [01, 02, 03, 08, 13, 14]
touches:
  - Sources/UI/Pane/**
  - Tests/UITests/PaneTests/**
parallel_safe: true
---

# Session 16: File Pane View

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 03, 08, 13, 14 artifacts. Read each handoff. Use `import DesignSystem`, `import Core`, `import FeaturesPreview`, `import FeaturesGit`. Drive the pane against any `FileSystemProvider`.

Mission
Build the centerpiece UI component: a single file pane displaying a directory listing with selection, sort, filter, inline rename, drag/drop, keyboard navigation, and git-status decorations. The dual-pane shell (Session 26) will compose two of these.

Repository anchors
- Sources/UI/Pane/FilePane.swift (top-level SwiftUI view)
- Sources/UI/Pane/FilePaneViewModel.swift (`@Observable`)
- Sources/UI/Pane/FileListView.swift (NSTableView/NSOutlineView via NSViewRepresentable for performance)
- Sources/UI/Pane/Selection.swift
- Sources/UI/Pane/InlineRenameField.swift
- Sources/UI/Pane/DragDrop.swift (NSPasteboard + Operation handoff)
- Sources/UI/Pane/KeyboardNavigation.swift (arrow keys, type-ahead, F2 rename, Cmd+Delete)
- Sources/UI/Pane/StatusBar.swift (selection count, total size)
- Tests/UITests/PaneTests/*.swift (uses InMemoryFileSystemProvider from Core/Testing)

Tasks
1. `FilePaneViewModel` is `@MainActor` and `@Observable`; holds the current `FilePath`, sort + filter state, selection, and an async loader bound to a `FileSystemProvider`.
2. `FileListView` wraps an `NSTableView` (multi-column: name, size, modified, kind) via `NSViewRepresentable` for tens-of-thousands-of-rows performance.
3. Inline rename via `InlineRenameField`; dispatches a `RenameStep.find`-equivalent rename through the provider directly (single-file rename, not the batch engine).
4. Drag/drop: drag-out promises the file via `NSFilePromiseProvider`; drop-in receives `NSPasteboard.PasteboardType.fileURL` and emits an `Operation` request on the view-model's continuation.
5. Keyboard: arrow keys move selection; type-ahead jumps to first match; `F2` opens inline rename; `Cmd+Delete` requests trash; `Space` toggles Quick Look via the preview service.
6. Git decorations: when a `GitStatusProvider` is provided, decorate rows with a status badge from the design system's icon registry.
7. Tests: open a path, assert listing; sort + filter behavior; selection ranges; rename success/failure; drag pasteboard payload contains the right URL list.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-16-handoff.md` describing the view-model contract, drag/drop pasteboard schema, and the integration points the dual-pane shell uses.

Quality gates
- `swift build --target UIPane`
- `swift test --filter PaneTests`
- `swiftformat --lint Sources/UI/Pane Tests/UITests/PaneTests`
- `swiftlint --strict --path Sources/UI/Pane`

Exit criteria
- Pane renders 50,000-row in-memory directories without dropping below 60fps when scrolling (verified by an FPS-instrumented test or a documented manual benchmark).
- Drag/drop pasteboard contains exactly the selected files' URLs in stable order.
- Keyboard map matches the spec above; verified by simulated key events in tests.
```
