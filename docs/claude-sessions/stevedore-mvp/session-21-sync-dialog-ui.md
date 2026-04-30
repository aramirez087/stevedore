---
session: 21
title: "Sync Dialog UI"
depends_on: [01, 02, 08, 11]
touches:
  - Sources/UI/SyncDialog/**
  - Tests/UITests/SyncDialogTests/**
parallel_safe: true
---

# Session 21: Sync Dialog UI

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 08, 11 artifacts. Read each handoff. Use `import FeaturesSync`, `import DesignSystem`.

Mission
Build the folder-comparison + sync dialog — picks left/right roots, shows the difference table, exposes mode selection (mirror / contribute / two-way) and ignore globs, lets the user preview the plan, then commits via the Operations engine integration declared by Session 26.

Repository anchors
- Sources/UI/SyncDialog/SyncDialog.swift (top-level sheet)
- Sources/UI/SyncDialog/SyncDialogViewModel.swift
- Sources/UI/SyncDialog/DifferenceTable.swift
- Sources/UI/SyncDialog/ModePicker.swift
- Sources/UI/SyncDialog/IgnoreGlobsEditor.swift
- Sources/UI/SyncDialog/PlanPreview.swift
- Tests/UITests/SyncDialogTests/*.swift

Tasks
1. `SyncDialogViewModel` (`@MainActor`, `@Observable`) holds the two roots, options, the comparison result (paginated), the derived plan, and a "running" status enum. Wraps a `FolderComparator` and `SyncEngine` from Session 11 via injected dependencies.
2. `DifferenceTable` shows columns (left path, right path, status, size delta) with status filters (matched/modified/leftOnly/rightOnly). Multi-select with shift/cmd; selection drives plan inclusion.
3. `ModePicker` segmented control: One-way Mirror, One-way Contribute, Two-way. Visual hint shows arrow direction.
4. `IgnoreGlobsEditor` lets users add/remove glob patterns; saved as part of a "saved sync" if the user chooses to bookmark the configuration.
5. `PlanPreview` lists the operations that will run, grouped by kind, with a count + total bytes summary at the bottom. "Apply" button is disabled until at least one row is included.
6. Tests: render with a synthetic comparison result, filter toggles, plan preview math, mode switches change derived plan, "Apply" callback fires with the correct plan.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-21-handoff.md` covering the dialog's IO contract (roots in, plan out) and the saved-sync schema.

Quality gates
- `swift build --target UISyncDialog`
- `swift test --filter SyncDialogTests`
- `swiftformat --lint Sources/UI/SyncDialog Tests/UITests/SyncDialogTests`
- `swiftlint --strict --path Sources/UI/SyncDialog`

Exit criteria
- The dialog runs a full cycle (open → compare → tweak options → preview → apply) using only injected fakes in tests.
- Difference table virtualizes — verified by rendering a 10,000-row diff without dropped frames.
- ModePicker emits exactly one option-change event per user click.
```
