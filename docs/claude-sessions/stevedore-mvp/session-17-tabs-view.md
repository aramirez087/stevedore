---
session: 17
title: "Tabs View"
depends_on: [01, 02, 08]
touches:
  - Sources/UI/Tabs/**
  - Tests/UITests/TabsTests/**
parallel_safe: true
---

# Session 17: Tabs View

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 08 artifacts. Read each handoff. Use `import Core`, `import DesignSystem`.

Mission
Build the per-pane tab strip — open, close, reorder, switch, drag-to-detach (deferred to a future session) — exposing a clean `TabStripViewModel` so the dual-pane shell composes one strip per pane.

Repository anchors
- Sources/UI/Tabs/TabStrip.swift (SwiftUI)
- Sources/UI/Tabs/TabStripViewModel.swift
- Sources/UI/Tabs/TabItemView.swift
- Sources/UI/Tabs/TabContextMenu.swift
- Sources/UI/Tabs/TabReorder.swift (drag-within-strip)
- Tests/UITests/TabsTests/*.swift

Tasks
1. `TabStripViewModel` (`@MainActor`, `@Observable`) holds an ordered `[Tab]`, `selectedTabID`, and exposes `open`, `close`, `select`, `reorder` methods. Maintains a small undo stack for "reopen recently closed".
2. `TabStrip` view renders the strip with horizontal scroll when overflow occurs, a leading "+" button, and a per-tab close affordance. Use only `DesignSystem` tokens.
3. `TabItemView` shows folder name + truncated path tooltip; loading shimmer when the underlying pane is paginating.
4. `TabContextMenu` offers: Close, Close Others, Close to the Right, Duplicate, Pin, Reopen Closed.
5. `TabReorder` supports horizontal drag with a placeholder gap; uses SwiftUI `.onDrag`/`.onDrop` with a Tab-ID pasteboard type.
6. Persist tab state via a callback (`onChange`) that the host wires to the Settings session's `WorkspacesRepository`. Do NOT depend on Settings here — keep the strip portable.
7. Tests: open/close/reorder behavior, undo stack of recently closed, context menu actions invoke the right view-model method.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-17-handoff.md` describing the view-model API and the tab persistence handshake the shell will wire.

Quality gates
- `swift build --target UITabs`
- `swift test --filter TabsTests`
- `swiftformat --lint Sources/UI/Tabs Tests/UITests/TabsTests`
- `swiftlint --strict --path Sources/UI/Tabs`

Exit criteria
- View-model is independent of file-system providers — reusable in tests with stub `Tab` values.
- Reorder maintains stable identity (selectedTabID stays valid across moves).
- Context menu entries each have a passing unit test.
```
