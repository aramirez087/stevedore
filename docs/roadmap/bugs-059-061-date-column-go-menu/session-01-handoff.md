# Session 01 Handoff — Audit Bugs #059, #060, #061

**Session:** 01 — Charter audit (read-only)
**Date:** 2026-05-03
**Mode:** Diagnostic only — no source edits
**Next session:** 02 (apply mechanical edits per this handoff)

## Summary

- **Bug #059** — fix planned in `Sources/UI/MainWindow/PaneHost.swift` (lines 224–229). Date `Text` has frame width `90` and no `.lineLimit(1)` — wraps for any locale-default date that exceeds the column width. Proposed change: width `130` + `.lineLimit(1)`.
- **Bug #060** — root cause shared with #059. Both panes use the **same** `LocalFileSystemProvider` instance and identical enumeration options, so per-pane attribute divergence is impossible. The "right pane has no dates" symptom is a rendering side effect of the wrap in #059 when the right pane is narrow. **No separate code change planned.** Fallback escalation path documented below.
- **Bug #061** — **ALREADY FIXED.** `PaneHost.swift:50` emits with `.focusedSceneValue`; `GoMenu.swift:5` reads with `@FocusedValue`. This matches the operator-rules-mandated macOS 26 SDK pattern. Session 02 must NOT touch the focus-value wiring.

---

## Bug #059 — Date column wraps

### Root cause

`FileBrowserView` row layout (`Sources/UI/MainWindow/PaneHost.swift:224–229`) renders the modification date inside a fixed-width frame of `90` pt without applying `.lineLimit(1)`:

```swift
if let date = item.attributes.modificationDate {
    Text(date, style: .date)
        .font(self.theme.typography.caption)
        .foregroundStyle(self.theme.colors.textSecondary)
        .frame(width: 90, alignment: .trailing)
}
```

`Text(date, style: .date)` renders the user's locale-default long-style date (e.g. `"December 31, 2025"` in `en_US`, ~17 characters at caption font). At `90` pt and with no `.lineLimit`, SwiftUI wraps the string onto two lines, inflating row height and breaking column alignment. The same logic applies in both panes — the bug presents most strongly in the pane that is currently narrower in the dual-pane split.

### File + line numbers

- File: `Sources/UI/MainWindow/PaneHost.swift`
- Lines: `224–229` (the `if let date = item.attributes.modificationDate { … }` block)

### Proposed diff

```diff
 if let date = item.attributes.modificationDate {
     Text(date, style: .date)
         .font(self.theme.typography.caption)
         .foregroundStyle(self.theme.colors.textSecondary)
-        .frame(width: 90, alignment: .trailing)
+        .lineLimit(1)
+        .frame(width: 130, alignment: .trailing)
 }
```

**Modifier order rationale:** `.lineLimit(1)` is applied to the `Text` first so it reports a single-line ideal size. `.frame(width: 130, alignment: .trailing)` is applied last so it fixes the column width regardless of content length.

**Width rationale:** `130` pt comfortably fits `"December 31, 2025"` (`en_US` long-style, the longest common locale-default date) at the caption font, with margin for locales such as `de_DE` (`"31. Dezember 2025"`) that produce slightly longer strings. The prior `90` pt was chosen for short-style dates and does not match `Text(date, style: .date)` semantics.

### Verification (manual, post-Session 02)

1. `swift build` exits 0.
2. Launch the app; navigate the right pane to `~/Documents` (or any folder with multiple files). Confirm dates render on a single line, right-aligned, identical between panes.
3. Resize the split fraction so the right pane is the narrower pane. Dates remain on one line; rows do not change height.

---

## Bug #060 — Right pane no dates

### Root cause (shared with #059)

Audit of dependency-injection wiring confirms the two panes are **structurally identical** with respect to file metadata sourcing:

- `App/Stevedore/AppEnvironment.swift:50–51`:

  ```swift
  let leftSession = PaneSession(id: .left, initialPath: home, provider: localProvider)
  let rightSession = PaneSession(id: .right, initialPath: home, provider: localProvider)
  ```

  Both panes receive the **same** `LocalFileSystemProvider` instance and the **same** initial `home` path.

- `Sources/UI/MainWindow/PaneSession.swift` exposes `provider` as a single shared dependency (line 20). No branch on `.left` / `.right` exists anywhere in the file.

- `Sources/UI/MainWindow/PaneHost.swift:293–314` (`FileBrowserView.loadItems()`) is pane-agnostic: both panes hit `provider.enumerate(at:options: .default)`, sort identically, and assign once at the end. There is no `.task(id:)` re-entrancy that would overwrite items mid-load.

Because the provider, options, and target path are identical, `item.attributes.modificationDate` cannot legitimately be `nil` for the right pane while non-`nil` for the left. The reported asymmetry is therefore a **rendering symptom of bug #059**: when the right pane is narrower in the split (DualPaneLayout default `splitFraction = 0.5`, plus user resizes), the date `Text` at `90` pt with no `.lineLimit(1)` wraps to two lines and is visually clipped/eclipsed by the row baseline, producing the appearance of "no dates" even though the data is present.

The HStack budget (`Sources/UI/MainWindow/PaneHost.swift:205–230`) is roughly: icon ~20 pt + name (flex) + Spacer + size (80 pt) + date (90 pt) + `Spacing.sm` × 4. When the right pane is narrow, the flexible name column takes priority and the date frame triggers wrap rather than ellipsis, because no `.lineLimit` is set.

### Why no separate fix

Provider files are not in the Session 02 `touches` scope. Even if they were, the structural audit shows there is nothing to fix on the data side: the same provider returns the same `FileItem` values regardless of which `PaneSession` consumes the `AsyncSequence`. The #059 fix (width `130` + `.lineLimit(1)`) addresses the rendering wrap that is the actual user-visible defect.

### Fallback plan if symptom persists post-fix

If Session 03's manual verification shows the right pane still lacks dates **after** the #059 fix is applied, escalate as follows:

1. Add a one-shot diagnostic log inside `loadItems()` at `Sources/UI/MainWindow/PaneHost.swift:296–304` that prints `item.path.posixString` + `String(describing: item.attributes.modificationDate)` for each enumerated item, scoped to a single load.
2. Audit `LocalDirectoryEnumerator` (path noted in `.wolf/cerebrum.md`) to confirm `URLResourceMapperKeys` requests `.contentModificationDateKey`. If absent, add it to the prefetch set.
3. Inspect `URLResourceMapper`'s mapping from `URLResourceValues` to `FileItem.Attributes` to confirm the modification date is propagated, not dropped, when `nil`-checked.
4. Confirm there is no `.task(id:)` re-entrancy that overwrites `items` mid-load with a partially populated batch — current code uses `await … sorted`, then assigns once, so this is an unlikely cause but worth re-checking under heavy directories.

These steps require expanding Session 02's `touches` scope to include `Sources/FileSystem/Local/`. Do **not** preemptively expand scope: only escalate if the rendering fix proves insufficient.

---

## Bug #061 — Go menu non-functional

### Verdict: ALREADY FIXED

No code change is required in Session 02 for bug #061. The current source already implements the operator-rules-mandated macOS 26 SDK pattern.

### Evidence (file:line citations)

**Emitter side** — `Sources/UI/MainWindow/PaneHost.swift:50`:

```swift
.focusedSceneValue(\.paneCommandProxy, self.isActive ? self.buildProxy() : nil)
```

This attaches the proxy as a **scene-scoped** focused value, which propagates to menu-bar `Commands` regardless of whether keyboard focus is currently inside `PaneHost`'s subtree.

**Reader side** — `Sources/UI/Menus/Sections/GoMenu.swift:5`:

```swift
@FocusedValue(\.paneCommandProxy) private var proxy
```

`@FocusedValue` reads from the same `FocusedValues` storage that `.focusedSceneValue` writes to. This is the correct reader pattern on macOS 26 SDK because `@FocusedSceneValue` (the property wrapper) is **absent** from the macOS 26 swiftmodule (per operator rules and `.wolf/cerebrum.md` Key Learnings).

**FocusedValues entry** — `Sources/UI/Menus/PaneCommandProxy.swift:126–128`:

```swift
public extension FocusedValues {
    @Entry var paneCommandProxy: PaneCommandProxy?
}
```

The storage key is declared with the `@Entry` macro, the modern Swift 6 / macOS 26 declaration form.

This combination — `.focusedSceneValue` emitter + `@FocusedValue` reader + `@Entry` storage — exactly matches the pattern documented in operator rules section "Hard Constraints" and in `.wolf/cerebrum.md` Key Learnings (entries on `@FocusedSceneValue` removal and the corrected emitter pattern).

### What Session 02 must NOT do

- Do **not** change `PaneHost.swift:50` from `.focusedSceneValue` to `.focusedValue`. `.focusedValue` makes the proxy `nil` whenever keyboard focus is outside `PaneHost` (sidebar click, first launch, sheet dismiss), which is the original cause of the "Go menu non-functional" report. The current code is the fix.
- Do **not** change `GoMenu.swift:5` from `@FocusedValue` to `@FocusedSceneValue`. `@FocusedSceneValue` does not exist in the macOS 26 swiftmodule and would fail to compile.
- Do **not** add a parallel emitter for the same key. There is exactly one emitter (line 50) and it is correct.

### How Session 03 can re-verify the verdict in CI

Run these two greps to confirm the lines remain unchanged after Session 02 finishes:

```bash
grep -n 'focusedSceneValue(\\\\\\.paneCommandProxy' Sources/UI/MainWindow/PaneHost.swift
grep -n 'FocusedValue(\\\\\\.paneCommandProxy)'      Sources/UI/Menus/Sections/GoMenu.swift
```

Both must match. If either fails, bug #061 has regressed and Session 03 must restore the lines from this handoff.

---

## Inputs required by Session 02

- **Touched files:** `Sources/UI/MainWindow/PaneHost.swift` only (per Session 02 `touches` scope). One block of edits at lines 224–229.
- **No edits to `Sources/UI/Menus/`** — bug #061 is already correct on macOS 26 SDK; bug #060 has no menus involvement.
- **No edits to `App/Stevedore/AppEnvironment.swift`** — pane wiring is symmetric; #060 is a rendering symptom of #059.
- **No edits to `Sources/FileSystem/Local/`** — provider is shared and functioning identically per pane; do not pursue this path unless the fallback in §"Bug #060 → Fallback plan" triggers.
- **Tests:** Session 01 added no tests. Session 02 should not need to either, because the change is purely a UI layout adjustment (width + `.lineLimit`) with no observable behavior beyond visual rendering. If Session 03 disagrees, add a snapshot-style verification then; do not pre-emptively introduce snapshot infrastructure.
- **CI gates owned by Session 02:** `swift build` exits 0. `swiftformat Sources --lint` and `swiftlint --strict Sources` are full Definition of Done; Session 03 owns those + `swift test`.

---

## Open issues

- **`docs/bug-report-2026-05-03.md` is absent from the worktree.** The charter references this document for bug descriptions, but it does not exist on this branch. Session 01 derived bug descriptions from the operator rules + the charter task list verbatim; no details were invented. Recommendation: the next session (or an epic-author follow-up) should either create the canonical bug-report markdown or update charter language to reference the per-session task list as the source of truth.
- **No regressions found** in adjacent code during the audit. The `PaneSession` reentrancy contract (cerebrum entry on `navigate → onNavigate → updatePath`) is intact; the `@Observable` task retain-cycle pattern is correct elsewhere; the `PaneCommandProxy` `@Entry` declaration is current.
