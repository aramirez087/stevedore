---
session: 26
title: "Main Window & Dual-Pane Shell"
depends_on: [01, 02, 03, 07, 08, 09, 10, 13, 14, 16, 17, 18, 19, 20]
touches:
  - App/**
  - Sources/UI/MainWindow/**
  - Tests/UITests/MainWindowTests/**
parallel_safe: false
---

# Session 26: Main Window & Dual-Pane Shell

Paste this into a new Claude Code session:

```md
Continuity
Continue from Sessions 01, 02, 03, 07, 08, 09, 10, 13, 14, 16, 17, 18, 19, 20 artifacts. Read each handoff. This session composes everything the user sees on launch.

Mission
Wire the application together: a single window with a dual-pane layout (left pane + right pane, each with its own tab strip and toolbar), a shared sidebar, and a docked Transfers panel. Restore window state across launches. Provide the dependency-injection root where engines and providers are constructed.

Repository anchors
- App/Stevedore/StevedoreApp.swift (@main App, scene composition)
- App/Stevedore/AppEnvironment.swift (DI container — wires providers, engines, services)
- App/Stevedore/Info.plist (bundle id, capabilities, sandbox entitlements declared but disabled in dev)
- App/Stevedore/Stevedore.entitlements
- Sources/UI/MainWindow/MainWindowScene.swift
- Sources/UI/MainWindow/DualPaneLayout.swift
- Sources/UI/MainWindow/PaneHost.swift (per-pane composition: toolbar + tabs + FilePane)
- Sources/UI/MainWindow/WindowState.swift (split fraction, tab state, last paths — persisted)
- Sources/UI/Menus/AppCommands.swift (empty stub — Session 27 fills in)
- Tests/UITests/MainWindowTests/*.swift

Tasks
1. `AppEnvironment` constructs the local provider, the remote registry, the credentials store, settings store, logger, operation queue, sync engine, rename engine, preview service, git provider — once, owned by the App entry. Pass instances down via SwiftUI `Environment` keys.
2. `MainWindowScene` declares a `WindowGroup` with `.commands(AppCommands())` (the stub) and a single `MainWindowView` containing: leading sidebar, two `PaneHost`s separated by a draggable splitter, a trailing/bottom Transfers panel that auto-shows when the queue is non-empty.
3. `DualPaneLayout` manages the split fraction (0.2..0.8); persisted via `WindowState`.
4. `PaneHost` composes Toolbar + Tabs + FilePane for one pane, sharing a `PaneSession` view-model that owns the active provider, current path, history, and tabs.
5. Operation requests from FilePane drag/drop are routed into the shared `OperationQueue`; each pane's drop on the *other* pane initiates a copy/move operation with the right policy.
6. `WindowState` persists via the Settings session's `WorkspacesRepository`; restore on launch, snapshot on close. Includes split fraction, per-pane tabs, last selected sidebar item.
7. Sidebar selection updates the *active* pane (last clicked) — track active pane visually.
8. Tests: scene composes without crashing using the injected fakes; window state round-trips; pane-to-pane drop produces an `Operation` with the correct source/dest providers.

Deliverables
- All source files above.
- `docs/roadmap/stevedore-mvp/session-26-handoff.md` describing the DI wiring, window-state schema, active-pane semantics, and the menu-command extension point Session 27 will fill.

Quality gates
- `swift build`
- `swift test --filter MainWindowTests`
- `swiftformat --lint App Sources/UI/MainWindow Tests/UITests/MainWindowTests`
- `swiftlint --strict --path App --path Sources/UI/MainWindow`
- `xcodebuild -scheme Stevedore -destination 'platform=macOS' build`

Exit criteria
- App launches into a window showing two panes pointing at `~` with a working sidebar — verified by a UI smoke test that boots the scene and asserts visible panes.
- Drag-and-drop from one pane to the other enqueues a copy operation visible in the Transfers panel.
- Window state (split fraction + per-pane tabs) survives a relaunch in tests.
```
