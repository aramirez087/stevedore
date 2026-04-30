---
session: 22
title: "Multi-Rename Dialog UI"
depends_on: [01, 02, 08, 12]
touches:
  - Sources/UI/RenameDialog/**
  - Tests/UITests/RenameDialogTests/**
parallel_safe: true
---

# Session 22: Multi-Rename Dialog UI

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 08, 12 artifacts. Read each handoff. Use `import FeaturesRename`, `import DesignSystem`.

Mission
Build the batch-rename sheet — input is a list of `FileItem`s, output is a `RenameRecipe` and (on Apply) the executed result. Show a live preview table that updates as the recipe changes.

Repository anchors
- Sources/UI/RenameDialog/RenameDialog.swift
- Sources/UI/RenameDialog/RenameDialogViewModel.swift
- Sources/UI/RenameDialog/RecipeBuilder.swift (UI for adding/editing/removing steps)
- Sources/UI/RenameDialog/StepEditors/*.swift (one per `RenameStep` case)
- Sources/UI/RenameDialog/PreviewTable.swift
- Sources/UI/RenameDialog/SavedRecipesMenu.swift
- Tests/UITests/RenameDialogTests/*.swift

Tasks
1. `RenameDialogViewModel` (`@MainActor`, `@Observable`) holds the source items, the in-progress recipe, the planner output (live), and the executor's result on Apply.
2. `RecipeBuilder` lists the recipe steps with reorder / remove / disable affordances. A "+ Add step" menu inserts a new step editor.
3. One `StepEditor` view per `RenameStep` case — find/replace, regex, case, sequence numbering, trim, insert, extension. Each posts updates to the view-model debouncing keyboard input (200ms).
4. `PreviewTable` shows source name, arrow, target name, and a status icon (ok / collision / invalid). Collisions and invalids are highlighted; user cannot Apply while any row is invalid.
5. `SavedRecipesMenu` lets the user save a named recipe (handed off to Settings via callback) and recall it later.
6. Apply button calls a host-provided `apply(plan: [RenameOutcome])` callback — Session 26 will wire it to the executor + provider.
7. Tests: every step editor mutates the recipe correctly; preview reflects planner output; collision row blocks Apply; recipe save callback fires with the expected payload.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-22-handoff.md` covering the recipe persistence schema and the apply-callback contract.

Quality gates
- `swift build --target UIRenameDialog`
- `swift test --filter RenameDialogTests`
- `swiftformat --lint Sources/UI/RenameDialog Tests/UITests/RenameDialogTests`
- `swiftlint --strict --path Sources/UI/RenameDialog`

Exit criteria
- Preview is fully derived from inputs — no hidden state in views.
- Apply is disabled with a visible reason (tooltip + status row) whenever any row is invalid.
- Step editors are individually testable in isolation.
```
