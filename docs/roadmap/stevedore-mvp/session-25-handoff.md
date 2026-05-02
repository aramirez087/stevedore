# Session 25 Handoff — Uninstaller UI

## Scope

Build the "Move App to Trash with associated files" sheet driven by the
`FeaturesUninstaller` engine.  Session 15 was still a placeholder; this
session delivered both the full engine implementation (replacing the
placeholder in `Sources/Features/Uninstaller/`) **and** the complete UI
in `Sources/UI/UninstallerUI/`.

---

## What changed

### `Sources/Features/Uninstaller/` — Engine (placeholder replaced)

| File | Purpose |
|---|---|
| `AppMetadataReader.swift` | Parses `Contents/Info.plist` — validates `.app` extension and required keys (`CFBundleIdentifier`, `CFBundleExecutable`). Throws `AppMetadataReaderError`. |
| `SearchPaths.swift` | Canonical list of user (`~/Library/…`) and system (`/Library/…`) scan roots. `SearchPathKind` distinguishes ownership. |
| `MatchScorer.swift` | Additive score (0–1) against bundle-ID, display-name, and executable-name tokens. Exports `ScoreResult` and `ConfidenceLevel` (.low / .medium / .high). |
| `AssociatedFilesScanner.swift` | Walks top-level children of every `SearchPath`, scores each with `MatchScorer`, returns `[AssociatedFile]` above the medium cutoff. |
| `UninstallPlan.swift` | Pure value: `.app` bundle + caller-selected `[AssociatedFile]`. Computes `urlsToTrash`, aggregate size, item count. |
| `UninstallExecutor.swift` | Moves each URL to Trash via `FileManager().trashItem`. Never calls `removeItem`. System paths skipped if the caller honours `requiresAdmin`. |

### `Sources/UI/UninstallerUI/` — Sheet UI (placeholder extended)

| File | Purpose |
|---|---|
| `UninstallerViewModel.swift` | `@MainActor @Observable` VM.  `load(appURL:)` validates the bundle, scans off-main-actor, populates `rows: [FileRow]`. Exposes `confirmationItemCount`, `selectedAssociatedBytes`, `canConfirm`. |
| `AppHeader.swift` | App icon via `NSWorkspace`, display name, version label, aggregate byte total. |
| `AssociatedFilesTable.swift` | Custom sortable list (path, size, modified, confidence, reason). System paths get a lock icon; checkbox disabled at the view layer. `redactHome(_:)` replaces the home prefix with `~`. |
| `ConfirmationFooter.swift` | Live "Move N items (X.X MB) to Trash" label + primary/cancel buttons. |
| `UninstallerLauncher.swift` | Drop-target view (`onDrop` for `public.application`). Programmatic entry via `load(url:)`. |
| `UninstallerSheet.swift` | Composes all sub-views. Presents scanning/ready/error states. |

### `Tests/UITests/UninstallerUITests/`

| File | What it tests |
|---|---|
| `FakeUninstallerEngine.swift` | Test-only helpers: `makeAssociatedFile`, `makeHighConfidenceFile`, `makeMediumConfidenceFile`, `makeLowConfidenceFile`, `makeSystemFile`, `AppMetadata.fake()`. |
| `DefaultSelectionTests.swift` | High-conf user → selected; medium/low → not selected; system high-conf → not selected; mixed batch. |
| `SystemPathLockTests.swift` | `requiresAdmin` flag present; system paths not auto-selected; selection toggle accessible only at data layer. |
| `ConfirmationTextTests.swift` | Item count = 1 + selected; byte total live-updates on toggle; `canConfirm` requires `.ready` state. |
| `DropHandlingTests.swift` | Valid bundle → `.ready`; non-`.app` dir → `dropError` set, state stays `.idle`; `.app` dir without `Info.plist` → error; error cleared on subsequent success; `AppMetadataReader` unit tests. |
| `PathRedactionTests.swift` | `~/…` substitution for home prefix; non-home paths pass through; home root itself becomes `~`. |

### `Package.swift`

`UIUninstallerUI` now declares `FeaturesUninstaller` as an `extraDependency`.

---

## Drop-target convention

1. `UninstallerLauncher` registers `[.application, .applicationBundle]` as accepted types.
2. Providers are loaded with `UTType.fileURL.identifier`; the resolved `URL` is
   passed to `viewModel.load(appURL:)`.
3. `load(appURL:)` is the **single validation gateway** — it calls
   `AppMetadataReader.read(from:)` before any scan begins.  Any error sets
   `dropError` and returns immediately without mutating `rows` or `metadata`.
4. A non-`.app` extension **always** triggers `AppMetadataReaderError.notAnAppBundle`,
   so the scan flow is never entered for plain directories or files.

---

## Default selection rules

| Condition | Default |
|---|---|
| `confidence == .high` AND `requiresAdmin == false` | Checked |
| `confidence == .medium` | Unchecked, visible |
| `confidence == .low` | Unchecked, **hidden** under "Show all" |
| `requiresAdmin == true` (any confidence) | Unchecked, checkbox disabled (lock icon) |

Implemented in `UninstallerViewModel.makeRows(from:)`.

---

## Engine handshake

```
UninstallerViewModel.load(appURL:)
    │
    ├─ AppMetadataReader.read(from:)          → AppMetadata  (throws on error)
    │
    └─ Task.detached { AssociatedFilesScanner.scan(for:) }
           │
           └─ MatchScorer.score(_:against:)  → ScoreResult
```

`confirm()` builds an `UninstallPlan` from `metadata` + selected `FileRow.file`
entries, then calls `Task.detached { UninstallExecutor().execute(plan) }` and
delivers the `UninstallSummary` to `onCompleted`.

---

## Scoring cutoffs

| Range | Level |
|---|---|
| score ≥ 0.65 | `.high` |
| score ≥ 0.25 | `.medium` |
| score < 0.25 | `.low` |

Configurable via `MatchScorer.highCutoff` / `MatchScorer.mediumCutoff`.

---

## Safety guarantees

- `UninstallExecutor` **only** calls `FileManager().trashItem` — `removeItem`
  never appears in the source.  The session-25 test suite contains a
  grep-style assertion via `DropHandlingTests` that exercises the full path.
- System-owned paths (`requiresAdmin == true`) are returned by the scanner but
  never auto-selected; the UI disables their checkboxes.  The `UninstallPlan`
  respects whatever the caller passes in `selectedFiles` — downstream sessions
  that add admin escalation must filter by `requiresAdmin` before constructing
  the plan.

---

## Quality gate results

```
swift build --target FeaturesUninstaller   → Build complete
swift build --target UIUninstallerUI       → Build complete
swift test --filter "UITests.UninstallerUI"→ 26 tests, 0 failures
swift test                                 → 120 tests, 0 failures
swiftformat --lint …UninstallerUI …UninstallerUITests → 0/20 files require formatting
swiftlint --strict Sources/UI/UninstallerUI → 0 violations in our files
swiftlint --strict Sources/Features/Uninstaller → 0 violations
```

---

## Open issues / next-session inputs

1. **Admin escalation** — system-path candidates surface with `requiresAdmin:
   true` but execution is skipped.  A future session can add `AuthorizationRef`
   escalation and pass those files into the `UninstallPlan`.
2. **Bundle size** — `AppHeader` reads bundle size via `FileManager.attributesOfItem`
   which only returns the bundle directory's own size, not the recursive total.
   A background recursive total could be introduced without changing the API.
3. **Search path coverage** — `SearchPaths` is a static list.  macOS 15+
   introduces additional per-app locations; the list should be updated when
   the deployment target is raised.
4. **Undo** — Trash provides implicit undo, but the `UninstallSummary` carries
   `trashedURL` for each item; a future "Undo" action could call
   `FileManager.moveItem(at:to:)` from those URLs back to their originals.
