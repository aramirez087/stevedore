# Session 01 Handoff — FileBrowserView Bug Audit

## Scope

Read-only charter for the `FileBrowserView` bug-fix epic. This session
audited `Sources/UI/MainWindow/PaneHost.swift` and the surrounding
view-model + test scaffolding, confirmed root causes for `bug-049`
(no right-click context menu on file rows) and `bug-050` (single tap
navigates instead of selects), inventoried which file operations the
existing `FileSystemProvider` / `LocalFileOperations` already implement,
and produced the implementation blueprint Session 02 will execute.
No source or test files were modified.

## What changed

- **Added** `docs/roadmap/stevedore-file-browser-bugs/session-01-handoff.md`
  (this file).
- OpenWolf bookkeeping: appended one line to `.wolf/memory.md`; added
  the new handoff doc to `.wolf/anatomy.md`. No `.wolf/buglog.json`
  entries created — no fix was performed this session.

No code under `Sources/` or `Tests/` was touched. `swift build --target
MainWindow` continues to exit 0 with zero warnings.

## Confirmed root causes

### bug-049 — right-click on a file row produces no context menu

`FileBrowserView` row body lives at `Sources/UI/MainWindow/PaneHost.swift:210-243`.
The row `HStack` carries only:

```swift
.contentShape(Rectangle())
.onTapGesture {
    if item.kind == .directory {
        self.session.navigate(to: item.path)
    }
}
```

There is no `.contextMenu` modifier anywhere on the row. Verified by
`grep -n contextMenu Sources/UI`: the only matches in the entire UI tree
are `Sources/UI/Sidebar/Sections/ConnectionsSection.swift:20` and
`Sources/UI/Sidebar/Sections/FavoritesSection.swift:16`. Right-clicking
a file row therefore bubbles up to the surrounding `PaneHost` (whose
own `.onTapGesture` handles only left-click), and AppKit shows no menu.

### bug-050 — single tap navigates two folders deep

The same `.onTapGesture { … }` at line 238 has no `count:` argument
(default `count: 1`), and the closure calls `session.navigate(to:
item.path)` for any `.directory` item. Verified by `grep -n
selectedItemPath Sources` → 0 matches: there is no selection state in
the view at all. There is no `.onTapGesture(count: 2)` anywhere in
`PaneHost.swift`.

The "two levels deep" symptom from the bug report is consistent with
this: the user's first click navigates into folder A; the list re-renders
with folder B at roughly the same screen y-coordinate; the user's second
click (intended as the second half of a double-click on A) lands on
folder B and navigates again. Files (non-directory items) currently do
nothing on tap, which is also wrong — double-click-to-open is missing.

## Provider capabilities the menu can wire to

`FileSystemProvider` (`Sources/Core/Protocols/FileSystemProvider.swift`)
exposes only `attributes`, `enumerate`, `execute(OperationDescriptor)`,
and `watch`. There is no `trash` convenience method on the provider.
Trash is expressed as `OperationKind.trash` and dispatched through
`provider.execute(OperationDescriptor(kind: .trash, sources: [path]))`.
`LocalFileOperations.performTrash(_:)` (`Sources/FileSystem/Local/
LocalFileOperations.swift:241-255`) implements it via
`FileManager.trashItem(at:resultingItemURL:)`. The in-memory provider
used by tests (`Sources/Core/Testing/InMemoryFileSystemProvider.swift`)
does not implement `.trash`; calls there are incidental for tests.

Important plumbing constraint: `FileBrowserView` only has
`session.provider` as a direct hook. The authoritative
`FileOperationQueue` (`Sources/Features/Operations/OperationQueue.swift`)
lives on `MainWindowModel`, not on `PaneSession`. Session 02 has two
viable paths and must pick one:

1. **Direct provider call** —
   `Task { try await session.provider.execute(...) }`.
   Simpler, no queue plumbing, but bypasses the operation queue so the
   transfers panel won't show the trash op.
2. **Queue plumbing** — pass an `onTrash: ([FilePath]) -> Void` closure
   into `FileBrowserView` from `PaneHost`, which `MainWindowView` wires
   to `model.operationQueue.enqueue(...)`.

**Recommendation for Session 02: option 2 (closure injection).** It keeps
`FileBrowserView` free of `MainWindowModel` knowledge and matches the
existing `onDropped: ([FilePath]) -> Void` pattern already used by
`PaneHost.init`. Out of scope to wire in S01.

`Reveal in Finder` is independent of provider capability — it uses
`NSWorkspace.shared.activateFileViewerSelecting([url])` and is local-only.
Disable for `path.scheme != .local`.

`Open` for files uses `NSWorkspace.shared.open(url)`. Local-only.

## Context menu spec for Session 02

Order, label, action, disabled condition. Items remain visible-but-disabled
when not actionable (per `session-02-implement.md` task 4).

| # | Label | Action | Disabled when |
|---|---|---|---|
| 1 | **Open** | `item.kind == .directory` → `session.navigate(to: item.path)`; else `NSWorkspace.shared.open(URL(fileURLWithPath: item.path.posixString))` | `item.kind != .directory && item.path.scheme != .local` |
| 2 | **Reveal in Finder** | `NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path.posixString)])` | `item.path.scheme != .local` |
| 3 | *Divider* | — | — |
| 4 | **Move to Trash** | enqueue `OperationDescriptor(kind: .trash, sources: [item.path])` via injected closure (see above) | `item.path.scheme != .local` (`LocalFileOperations` is the only `.trash` impl) |
| 5 | *Divider* | — | — |
| 6 | **Copy** *(placeholder)* | no-op | always (MVP stub) |
| 7 | **Rename** *(placeholder)* | no-op | always (MVP stub) |

S02 minimum (per `session-02-implement.md`): items 1, 2, 4. Items 6–7
are optional placeholders — include only if S02 has time, otherwise drop.

## Gesture + selection design (code sketch)

Add state to `FileBrowserView` and a clear-on-navigation hook:

```swift
@State private var selectedItemPath: FilePath?

// inside body, after List(...):
.onChange(of: self.session.currentPath) { _, _ in
    self.selectedItemPath = nil
}
```

Row `HStack` modifier order — **double-tap declared before single-tap**
so SwiftUI gives it priority (otherwise the single-tap consumes the
first tap and the double never fires):

```swift
HStack { … }
    .background(self.rowBackground(for: item))
    .contentShape(Rectangle())
    .onTapGesture(count: 2) {
        if item.kind == .directory {
            self.session.navigate(to: item.path)
        } else if item.path.scheme == .local {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.path.posixString))
        }
    }
    .onTapGesture(count: 1) {
        self.selectedItemPath = item.path
    }
    .contextMenu { self.contextMenu(for: item) }

private func rowBackground(for item: FileItem) -> Color {
    self.selectedItemPath == item.path
        ? self.theme.colors.accent.opacity(0.15)
        : Color.clear
}
```

The `.contextMenu` is attached **after** the gestures. SwiftUI right-click
handling does not conflict with `.onTapGesture(count:)` — they listen on
different mouse buttons. Keep the `List(self.items, id: \.path)` form;
do not switch to `List(selection:)` (see gotchas).

## New tests Session 02 must add

Add to `Tests/UITests/MainWindowTests/MainWindowTests.swift` using
existing `makeTestPaneSession()` / `InMemoryFileSystemProvider` from
`MainWindowTestSupport.swift`. The fakes already produce `FileItem`
rows; no new fakes needed.

| # | Test | Asserts |
|---|---|---|
| T1 | `testFileBrowserSingleTapDoesNotNavigate` | After driving the single-tap closure on a directory item, `session.currentPath` is unchanged. |
| T2 | `testFileBrowserDoubleTapNavigatesToDirectory` | After driving the double-tap closure, `session.currentPath == directoryItem.path`. |
| T3 | `testFileBrowserDoubleTapOnFileDoesNotNavigate` | `session.currentPath` unchanged on double-tap of a non-directory item. |
| T4 | `testFileBrowserSelectionClearsOnNavigation` | Set `selectedItemPath`, navigate via `session.navigate(to:)`, selection becomes `nil`. |
| T5 | `testFileBrowserViewComposesWithContextMenu` | `NSHostingView(rootView: FileBrowserView(session:))` instantiates without crash — smoke test that the `.contextMenu` modifier compiles and renders. |

**Mechanism note for S02:** `FileBrowserView` is currently `private`
inside `PaneHost.swift` (line 176). S02 has two options to make tests
possible:

- **(a)** Promote `FileBrowserView` to `internal` so tests in the
  `@testable import MainWindow` target can construct it directly.
- **(b)** Extract the tap/selection logic into a small `@MainActor`
  view-model type (`FileBrowserModel`) that is `internal`/testable; the
  view calls into it. Cleaner and matches the existing `PaneSession` /
  `PaneToolbarViewModel` pattern, but more code.

S01 recommends **(a)** — minimum diff, and the gesture closures are
trivial enough that they don't need their own type.

## SwiftUI gotchas — must read before Session 02

1. **Gesture priority.** `.onTapGesture(count: 2)` must be declared
   *before* `.onTapGesture(count: 1)`. Reverse order causes single-tap
   to consume the gesture and double-tap never fires.
2. **Right-click vs. tap gesture.** macOS `.contextMenu` reacts to
   right-click only; `.onTapGesture` reacts to left-click. They do not
   conflict.
3. **`List` selection.** Do **not** use the `List(selection:)` API in
   parallel — it competes with manual `selectedItemPath` state and
   causes double highlights / focus rings. Keep the
   `List(self.items, id: \.path)` form already in use.
4. **Re-render churn.** `selectedItemPath` is `@State` in the view, not
   on `PaneSession`. Selection is intentionally pane-local and resets
   on navigation via `onChange(of: session.currentPath)`.
5. **`Sendable`.** `FilePath` is `Sendable` (declared in `Core`); using
   it in `@State` and in trailing closures is fine under Swift 6 strict
   concurrency.
6. **Trash on remote schemes.** `OperationKind.trash` is implemented
   only in `LocalFileOperations`. Do not attempt it on `path.scheme !=
   .local`; keep the menu item visible-but-disabled.
7. **Focus / activation.** `PaneHost`'s outer `.onTapGesture {
   self.onActivate() }` (line 43) should still fire when a row is
   tapped because tap gestures bubble. Verify in T5 that activating a
   pane by clicking a row still works; if blocked, use
   `.simultaneousGesture` on the outer view or wrap row taps with
   `.highPriorityGesture`.

## Decisions

- **Closure injection over direct provider call** for the Trash menu
  item. Mirrors the existing `onDropped` pattern in `PaneHost.init` and
  routes the operation through `FileOperationQueue` so the transfers
  panel can show it. (See "Provider capabilities" above.)
- **`internal` over view-model extraction** for testability. Promoting
  `FileBrowserView` from `private` to `internal` is a one-keyword diff;
  extracting a model is more code for negligible benefit while the view
  has only two pieces of state (`selectedItemPath`, `items`).
- **Double-tap before single-tap** in modifier order. This is a hard
  SwiftUI requirement; reversing the order silently breaks double-tap.
- **Visible-but-disabled menu items** for non-local schemes. Matches
  the explicit instruction in `session-02-implement.md` task 4 and
  gives users feedback about *why* the action is unavailable.

## Open issues / risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Outer `PaneHost.onTapGesture { onActivate }` swallows row taps | medium | Confirm in T5 smoke test; if blocked, use `.simultaneousGesture` on the outer view or wrap row taps with `.highPriorityGesture`. |
| `FileBrowserView` is `private`, blocking direct test construction | high (will block S02 tests) | Promote to `internal` (recommended) or extract a view-model. |
| Trash routing requires `MainWindowModel` access | medium | Closure injection (`onTrash`) plumbed `MainWindowView` → `PaneHost` → `FileBrowserView`, mirroring `onDropped`. Fall back to direct `provider.execute` for MVP if S02 runs short on time. |
| Single-tap vs. double-tap timing on macOS feels sluggish | low | SwiftUI uses the system double-click interval. Acceptable for MVP. If users complain, S03+ can swap to `TapGesture(count: 2).exclusively(before: TapGesture(count: 1))`. |
| `swiftformat --lint` / `swiftlint --strict` reject the new modifier order | low | Run both locally in S02 before opening the PR. Configs at repo root are authoritative. |

No defects spotted outside the `touches:` scope this session.

## Next-session inputs

Session 02 must read, in order:

1. This handoff (`docs/roadmap/stevedore-file-browser-bugs/session-01-handoff.md`).
2. `Users/aramirez/Code/stevedore/docs/claude-sessions/stevedore-file-browser-bugs/session-02-implement.md`
   (the S02 prompt + `touches:` glob).
3. `Sources/UI/MainWindow/PaneHost.swift` lines 13-115 (PaneHost wiring,
   for `onTrash` plumbing) and 176-274 (FileBrowserView, the patient).
4. `Sources/UI/MainWindow/PaneSession.swift` (provider + navigate API).
5. `Sources/FileSystem/Local/LocalFileOperations.swift:241-255`
   (`performTrash` — confirms `.trash` is implemented for `.local`).
6. `Tests/UITests/MainWindowTests/MainWindowTestSupport.swift` (factories
   for new tests; no new fakes required).
7. `Tests/UITests/MainWindowTests/MainWindowTests.swift` (existing
   `MainWindowTests` class — append the five new T1-T5 tests there).

## Verification

```sh
$ swift build --target MainWindow 2>&1 | tail -5
```

Expected: exit 0, zero warnings (no code changes were made this session).
Actual outcome recorded in commit. Quality gate passed.

S02 quality gates (for reference; **not** run this session):

```sh
swift build --target MainWindow -Xswiftc -warnings-as-errors 2>&1 | tail -10
swift test --filter MainWindowTests 2>&1 | tail -20
swiftformat Sources/UI/MainWindow Tests/UITests/MainWindowTests --lint
swiftlint --strict Sources/UI/MainWindow Tests/UITests/MainWindowTests
```
