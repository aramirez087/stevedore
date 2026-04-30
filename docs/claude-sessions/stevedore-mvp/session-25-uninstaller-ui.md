---
session: 25
title: "Uninstaller UI"
depends_on: [01, 02, 08, 15]
touches:
  - Sources/UI/UninstallerUI/**
  - Tests/UITests/UninstallerUITests/**
parallel_safe: true
---

# Session 25: Uninstaller UI

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 08, 15 artifacts. Read each handoff. Use `import FeaturesUninstaller`, `import DesignSystem`.

Mission
Build the "Move App to Trash with associated files" sheet — drop an .app onto it (or trigger from the menu), show associated files with confidence scores, let the user opt-in/out per item, and execute via the engine.

Repository anchors
- Sources/UI/UninstallerUI/UninstallerSheet.swift
- Sources/UI/UninstallerUI/UninstallerViewModel.swift
- Sources/UI/UninstallerUI/AssociatedFilesTable.swift
- Sources/UI/UninstallerUI/AppHeader.swift (icon, name, version, size)
- Sources/UI/UninstallerUI/ConfirmationFooter.swift
- Tests/UITests/UninstallerUITests/*.swift

Tasks
1. `UninstallerViewModel` (`@MainActor`, `@Observable`) wraps the Uninstaller engine — runs the metadata reader + associated-files scanner and projects results to the view.
2. `AppHeader` shows the app icon (extracted via NSWorkspace), display name, version, total bytes (app bundle + selected associated files).
3. `AssociatedFilesTable` lists each candidate with: include checkbox, path (with `~` redaction), size, last-modified, confidence score, reason. Columns sortable. System paths flagged with a lock icon and disabled.
4. Defaults: high-confidence items checked; medium-confidence unchecked but visible; low-confidence collapsed under "Show all".
5. `ConfirmationFooter` shows "Move N items (X.X MB) to Trash" with a primary button. Secondary "Cancel" closes the sheet without changes.
6. Drop-target: dropping an `.app` URL onto the sheet (or a separate launcher view in `UninstallerLauncher.swift`) populates the metadata. Verify Info.plist before scanning.
7. Tests: synthetic engine fakes; assert default selections, sort orders, system-path lock, confirmation text, drop handling for valid vs invalid bundles.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-25-handoff.md` covering the drop-target convention, default selection rules, and the engine handshake.

Quality gates
- `swift build --target UIUninstallerUI`
- `swift test --filter UninstallerUITests`
- `swiftformat --lint Sources/UI/UninstallerUI Tests/UITests/UninstallerUITests`
- `swiftlint --strict --path Sources/UI/UninstallerUI`

Exit criteria
- System-owned paths are visibly disabled and cannot be selected — verified by an interaction test.
- Confirmation footer text reflects the current selection live (no stale totals).
- Drop of a non-bundle directory shows an inline error and does not enter the scan flow.
```
