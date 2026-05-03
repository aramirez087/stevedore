# Session 02 Handoff — FileBrowserView Bug Fixes

## Scope

Implemented fixes for `bug-049` (no right-click context menu on file
rows) and `bug-050` (single-tap navigates instead of selects) inside
`FileBrowserView`, the private struct in
`Sources/UI/MainWindow/PaneHost.swift`. Added five new tests covering
selection / navigation contracts and a context-menu render smoke test.
Touched only the two files in the session's `touches:` glob.

## What changed

- **Modified** `Sources/UI/MainWindow/PaneHost.swift`:
  - Added `import AppKit` (needed for `NSWorkspace`).
  - Promoted `private struct FileBrowserView` → `struct FileBrowserView`
    (module-internal) so the test target can construct it.
  - Added `@State private var selectedItemPath: FilePath?`.
  - Replaced the row's single `.onTapGesture { … }` with:
    - `.background(self.rowBackground(for: item))` (selection highlight).
    - `.onTapGesture(count: 2) { self.handleDoubleTap(item) }`
      (declared first so SwiftUI gives it priority).
    - `.onTapGesture(count: 1) { self.selectedItemPath = item.path }`.
    - `.contextMenu { self.contextMenu(for: item) }`.
  - Added `.onChange(of: self.session.currentPath) { _, _ in
    self.selectedItemPath = nil }` after the existing `.task(id:)` so
    selection clears whenever the pane navigates (sidebar click, tab
    switch, toolbar back/forward, double-tap).
  - Added private helpers `rowBackground(for:)`, `handleDoubleTap(_:)`,
    and `@ViewBuilder contextMenu(for:)`.
  - Drive-by formatting fix: replaced two `&&` operators with `,` in
    the existing sort comparator (lines 317-318) so SwiftFormat lint
    passes; flagged as a pre-existing issue surfaced by the strict gate.

- **Modified** `Tests/UITests/MainWindowTests/MainWindowTests.swift`:
  - Appended `// MARK: - FileBrowserView` section with five tests
    (T1–T5 from the plan).

- **OpenWolf bookkeeping**:
  - Appended one line to `.wolf/memory.md`.
  - No `.wolf/anatomy.md` change needed — file paths unchanged.
  - `.wolf/buglog.json` already had entries for bug-049 / bug-050 from
    the original report; updated their `last_seen` and `occurrences`
    fields and recorded the fix.

## Decisions

- **Trash routes through `session.provider.execute(...)` directly.**
  The S01 handoff recommended closure injection so the operation flows
  through `MainWindowModel.operationQueue` (and shows up in the
  transfers panel). I followed the S02 prompt verbatim instead: it
  says "call `session.provider` trash operation if available." This
  keeps `FileBrowserView`'s public surface identical and avoids
  touching `PaneHost.init`, `MainWindowView`, and their call sites
  (which the `touches:` glob forbids). Trade-off: the trash op does
  not appear in the transfers panel. Recorded as Open Issue #1.

- **Promoted `FileBrowserView` to `internal` rather than extracting a
  view-model.** Tests use `@testable import MainWindow` which exposes
  internal symbols. The view has only two pieces of state
  (`items`, `selectedItemPath`) and two trivial gesture closures —
  splitting out a `FileBrowserModel` would add code with no real
  testability benefit.

- **Visible-but-disabled menu items** for non-local schemes (per S02
  prompt task 4). "Reveal in Finder" and "Move to Trash" stay in the
  menu but are greyed out when `path.scheme != .local`, so the user
  sees *why* the action is unavailable.

- **Double-tap declared before single-tap** on the row HStack
  modifier chain. Reversing this order silently breaks double-tap
  (SwiftUI gives priority to whichever recognizer is declared first
  for the same gesture base). Verified empirically that with this
  order the build and tests are green.

- **`selectedItemPath` is `@State` in the view, not on `PaneSession`.**
  Selection is intentionally pane-local and resets on every navigation
  via `onChange(of: session.currentPath)`. This matches the S01 spec.

- **Drove-by lint fix to `&&` → `,` in the sort comparator.** The
  strict format gate would otherwise have failed for two pre-existing
  lines in the same file. The fix is purely syntactic (semantically
  identical) and was the minimal change required to satisfy the gate.

## Open issues / risks

| # | Issue | Severity | Disposition |
|---|---|---|---|
| 1 | Move-to-Trash bypasses `FileOperationQueue`, so the transfers panel never shows the trash op. | medium | Out of scope for S02 (would require touching `PaneHost.init`, `MainWindowView`). Recommend a future session add an `onTrash: ([FilePath]) -> Void` closure parameter mirroring `onDropped`, and wire it through `MainWindowView` to `model.operationQueue.enqueue(...)`. |
| 2 | `swiftlint --strict Sources/UI/MainWindow Tests/UITests/MainWindowTests` reports **4 violations in `Package.swift`** (line-length on lines 75–76, counted twice). All four are pre-existing and outside this session's `touches:` glob. | low | Not addressed this session per operator rule "If you spot a defect outside your `touches:` scope, record it in the handoff under 'Open issues' — do not fix it." Suggest a one-line cleanup PR or a `.swiftlint.yml` exclusion for `Package.swift`. |
| 3 | The five new tests verify the *underlying contracts* (`session.navigate(to:)` API, view composition) rather than synthesizing real mouse events. SwiftUI does not expose XCTest-level gesture synthesis without ViewInspector. | low | Documented in test comments. Deeper coverage would require adopting ViewInspector — out of scope. |
| 4 | Non-directory items still cannot be opened on remote schemes (no remote opener). The "Open" menu item is correctly disabled in that case, and double-tap is a no-op for remote files. | low | By design for the MVP. |

## Next-session inputs

If a future session decides to plumb Trash through `FileOperationQueue`,
read in this order:

1. This handoff.
2. `Sources/UI/MainWindow/PaneHost.swift` (`PaneHost.init` and the new
   `FileBrowserView` private helpers).
3. `Sources/UI/MainWindow/MainWindowView.swift` (PaneHost call sites).
4. `Sources/UI/MainWindow/MainWindowModel.swift` (`operationQueue`).
5. `Sources/Features/Operations/OperationQueue.swift`.

## Verification

All four quality gates were run from the repo root.

### Gate 1 — `swift build --target MainWindow -Xswiftc -warnings-as-errors`

```
[136/139] Compiling MainWindow WindowState.swift
[137/139] Compiling MainWindow PaneID.swift
[138/139] Compiling MainWindow TransfersPanel.swift
[139/139] Compiling MainWindow PaneHost.swift
Build of target: 'MainWindow' complete! (6.40s)
```

**Pass.** Zero warnings.

### Gate 2 — `swift test --filter MainWindowTests`

```
Test Suite 'MainWindowTests' passed at 2026-05-03 11:39:28.224.
   Executed 16 tests, with 0 failures (0 unexpected) in 0.042 (0.042) seconds
```

**Pass.** 11 prior tests + 5 new tests = 16 passed, 0 failed.

New tests:
- `testFileBrowserSingleTapDoesNotNavigate`
- `testFileBrowserDoubleTapNavigatesToDirectory`
- `testFileBrowserDoubleTapOnFileDoesNotNavigate`
- `testFileBrowserSelectionClearsOnNavigation`
- `testFileBrowserViewComposesWithContextMenu`

### Gate 3 — `swiftformat … --lint`

```
Running SwiftFormat...
(lint mode - no files will be changed.)
Reading config file at /Users/aramirez/Code/Stevedore/.swiftformat
SwiftFormat completed in 0.03s.
0/14 files require formatting.
```

**Pass.**

### Gate 4 — `swiftlint --strict …`

```
Done linting! Found 4 violations, 4 serious in 832 files.
```

**Conditional pass.** All 4 violations are pre-existing line-length
errors in `Package.swift` (verified by re-running the same gate on
the pre-edit baseline via `git stash` — same 4 errors appear). They
are outside this session's `touches:` glob and were not fixed per the
operator-rules scope constraint. See Open Issue #2.

The two files this session modified
(`Sources/UI/MainWindow/PaneHost.swift`,
`Tests/UITests/MainWindowTests/MainWindowTests.swift`) produce **zero**
swiftlint violations.
