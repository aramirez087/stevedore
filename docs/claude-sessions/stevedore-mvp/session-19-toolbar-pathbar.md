---
session: 19
title: "Toolbar & Path Bar"
depends_on: [01, 02, 08]
touches:
  - Sources/UI/Toolbar/**
  - Tests/UITests/ToolbarTests/**
parallel_safe: true
---

# Session 19: Toolbar & Path Bar

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 08 artifacts. Read each handoff.

Mission
Build the per-pane toolbar (back/forward/up navigation, view-mode picker, search, refresh, new-folder) and the breadcrumb path bar that lets the user jump anywhere in the current path with a click.

Repository anchors
- Sources/UI/Toolbar/PaneToolbar.swift
- Sources/UI/Toolbar/PaneToolbarViewModel.swift
- Sources/UI/Toolbar/PathBar.swift
- Sources/UI/Toolbar/PathBarSegment.swift
- Sources/UI/Toolbar/HistoryStack.swift (back/forward stacks)
- Sources/UI/Toolbar/SearchField.swift (uses DesignSystem.SDSearchField)
- Tests/UITests/ToolbarTests/*.swift

Tasks
1. `PaneToolbarViewModel` is `@Observable`; exposes `goBack`, `goForward`, `goUp`, `refresh`, `newFolder`, `setViewMode`, `setSearch` — all routed via callbacks (no direct provider deps).
2. `HistoryStack` records visited `FilePath`s with capped capacity (default 64); supports back/forward like a browser; clears forward on new navigation.
3. `PathBar` renders breadcrumb segments derived from the current `FilePath`; clicking a segment emits a navigation request.
4. `PathBarSegment` shows a chevron between segments, supports right-arrow to open a quick subfolder picker (popover with directory contents).
5. `SearchField` debounces input (250ms) and emits the term via callback; a Clear button resets it.
6. View-mode picker offers `list | columns | icons` — but only `list` is wired in MVP; the others emit "not yet implemented" via a delegate hook.
7. Tests: history navigation invariants (back from root is no-op; forward cleared on new navigation); breadcrumb derivation from various path shapes (home, /, mounted volume, remote scheme); search debounce (asserts only one fire per burst).

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-19-handoff.md` documenting the callback contract the shell must satisfy.

Quality gates
- `swift build --target UIToolbar`
- `swift test --filter ToolbarTests`
- `swiftformat --lint Sources/UI/Toolbar Tests/UITests/ToolbarTests`
- `swiftlint --strict --path Sources/UI/Toolbar`

Exit criteria
- Toolbar/PathBar require zero file-system or network access at construction time.
- Path-bar overflow handles very long paths by collapsing middle segments behind an ellipsis menu.
- Search debounce verified deterministically with an injected clock.
```
