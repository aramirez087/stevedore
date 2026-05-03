---
session: 1
title: "Charter: Audit FileBrowserView and plan both bug fixes"
depends_on: []
touches:
  - docs/roadmap/stevedore-file-browser-bugs/session-01-handoff.md
parallel_safe: false
model: "opus"
---

# Session 01: Charter — FileBrowserView Bug Audit

Paste this into a new Claude Code session:

```md
## Mission
Audit `FileBrowserView` in `Sources/UI/MainWindow/PaneHost.swift`, confirm the root causes of bug-049 and bug-050, and produce a concrete implementation plan for Session 02.

## Repository anchors
- `Sources/UI/MainWindow/PaneHost.swift` — contains FileBrowserView (the patient)
- `Sources/UI/MainWindow/PaneSession.swift` — navigate(to:) and provider
- `Sources/UI/Toolbar/PaneToolbarViewModel.swift` — canGoBack/canGoForward
- `Tests/UITests/MainWindowTests/MainWindowTests.swift` — existing tests
- `Tests/UITests/MainWindowTests/MainWindowTestSupport.swift` — test fakes

## Tasks
1. Read all five files listed above in full.
2. Confirm bug-049: verify no `.contextMenu` modifier exists anywhere on FileBrowserView rows.
3. Confirm bug-050: verify `.onTapGesture` (count 1) is the only tap handler, and that no `selectedItemPath` state exists.
4. Identify which file operations are available via `PaneSession` / `LocalFileSystemProvider` that a context menu can wire to for MVP (e.g. trash, open). Note stubs that must remain no-ops.
5. Design the context menu item list: what to show, which actions are real vs. placeholder, disabled states.
6. Design the selection + navigation gesture split: `onTapGesture(count: 2)` for open/navigate, `onTapGesture(count: 1)` for selection. Plan the `@State selectedItemPath: FilePath?` and how row highlight is applied.
7. Identify any new tests that Session 02 must add to `MainWindowTests.swift`.
8. Write the handoff doc.

## Deliverables
- `docs/roadmap/stevedore-file-browser-bugs/session-01-handoff.md` containing:
  - Confirmed root causes for both bugs
  - Exact context menu item list with action stubs noted
  - Gesture design (code-sketch level, not full implementation)
  - List of new tests Session 02 must add
  - Any SwiftUI gotchas to watch (e.g. gesture priority, List row selection vs onTapGesture interaction)

## Quality gates
    swift build --target MainWindow 2>&1 | tail -5

## Exit criteria
- Handoff doc exists and covers all design decisions listed in Tasks.
- `swift build --target MainWindow` exits 0 (charter makes no code changes).
```
