# Session 19 Handoff — Toolbar & Path Bar

## Scope

Implement the per-pane toolbar (back/forward/up navigation, view-mode picker, search with
250 ms debounce, refresh, new-folder) and the breadcrumb path bar that lets the user jump
anywhere in the current path with a click. All behavior is routed through callbacks — the
ViewModel performs zero file-system or network access.

## What changed

### `Package.swift`
- `UIToolbar` `extraDependencies` changed from `[]` to `[.target(name: "DesignSystem")]`.
  This is an internal target dependency (not a new external package) and is permitted by the
  Session 01 freeze rule.

### `Sources/UI/Toolbar/` — deleted Placeholder.swift; added:
- `UIToolbarModule.swift` — preserves `UIToolbarModule.moduleName = "UIToolbar"` sentinel.
- `ViewMode.swift` — `public enum ViewMode: String, Sendable, CaseIterable { list, columns, icons }`.
- `HistoryStack.swift` — capped back/forward stack (`defaultCapacity = 64`); pure `struct`.
- `SearchDebouncer.swift` — `@MainActor @Observable` class; injectable `SleepFunction` typealias
  for deterministic testing.
- `PaneToolbarViewModel.swift` — `@MainActor @Observable` class; exposes `goBack`, `goForward`,
  `goUp`, `refresh`, `newFolder`, `setViewMode`, `navigate(to:)`; all side-effects routed via
  callbacks.
- `SearchField.swift` — `SDSearchField` + clear button wired to `SearchDebouncer`.
- `PathBarSegment.swift` — single breadcrumb segment with chevron that opens a lazy subfolder
  popover; also defines top-level `PathSegmentData` and `BreadcrumbItem` helper types.
- `PathBar.swift` — breadcrumb row; derives segments from `FilePath`; collapses middle segments
  behind an ellipsis `Menu` when path depth exceeds `maxVisible = 5`.
- `PaneToolbar.swift` — composes all toolbar elements into a `VStack`.

### `Tests/UITests/ToolbarTests/` — new directory:
- `ToolbarTestSupport.swift` — shared `immediateSleep: SleepFunction` and `makePath` helper.
- `ToolbarTests.swift` — `@MainActor final class ToolbarTests: XCTestCase`; 23 tests.

## Decisions

- **`HistoryStack` as pure `struct`** — `Sendable`, no identity, trivially testable. Owned and
  mutated by the `@MainActor` ViewModel.
- **`canGoBack` requires `backStack.count > 1`** — index 0 is the oldest entry with no further
  back. `PaneToolbarViewModel.init` seeds the first entry via `history.navigate(to: initialPath)`,
  so `canGoBack` starts `false`.
- **`SleepFunction = @Sendable (Duration) async throws -> Void`** — matches `Task.sleep(for:)`;
  simpler than `any Clock<Swift.Duration>` existential on an `@Observable` class.
- **`PathSegmentData` and `BreadcrumbItem` at file scope** — SwiftLint `nesting` rule rejects
  types nested more than 1 level deep under `--strict`.
- **`PathBar.breadcrumbs` marked `internal`** — `@testable import UIToolbar` exercises derivation
  directly without spinning up a SwiftUI host.
- **Static `maxVisible = 5`** — deterministic; avoids `GeometryReader` complexity (post-MVP).
- **`setViewMode(.columns/.icons)` calls `onViewModeUnavailable`, does not change `viewMode`** —
  the shell decides how to surface "not yet implemented".
- **`searchDebouncer` publicly exposed on ViewModel** — shell wires `onFire` directly to its
  filter pipeline; no extra delegation layer needed.

## Shell callback contract (Session 26 — Main Window Shell)

Session 26 must wire the ViewModel before embedding `PaneToolbar`. All callbacks are optional
but the three marked **Required** must be wired for correct behavior:

```swift
let vm = PaneToolbarViewModel(initialPath: startingPath)

// Required — perform actual FS navigation
vm.onNavigate = { [weak paneController] path in
    Task { await paneController?.enumerate(path) }
}
// Required — trigger directory re-enumeration
vm.onRefresh = { [weak paneController] in
    Task { await paneController?.refresh() }
}
// Required — show new-folder dialog
vm.onNewFolder = { [weak paneController] in
    paneController?.showNewFolderSheet()
}
// Optional — surface "not in MVP" (alert or no-op)
vm.onViewModeUnavailable = { _ in }

// Wire search to pane filter
vm.searchDebouncer.onFire = { [weak paneController] term in
    paneController?.filterItems(matching: term)
}

// Embed in window:
PaneToolbar(viewModel: vm)

// CRITICAL — all external navigations (e.g. double-click in file pane) must
// go through vm.navigate(to:) to keep history in sync. Never mutate
// vm.currentPath directly.
```

## Open issues / risks

1. **Overflow is width-agnostic** — `maxVisible = 5` is a hard count, not a measured pixel
   width. Very long component names can overflow the `ScrollView`. Post-MVP: switch to
   `GeometryReader`-driven collapse.
2. **`subfolderProvider` default is `{ _ in [] }`** — `PathBarSegment` and `PathBar` both
   default to an empty provider. Session 26 must supply a real provider (e.g. querying the
   active `FileSystemProvider`) for the subfolder popover to function.
3. **View-mode columns/icons** — `setViewMode(.columns/.icons)` fires `onViewModeUnavailable`
   and does not change `viewMode`. The shell may show an alert or ignore it; implement in a
   post-MVP session.
4. **`PaneToolbar` does not inject `subfolderProvider`** — the `PaneToolbar` view creates
   `PathBar` without a `subfolderProvider`. Session 26 should expose `subfolderProvider` on
   `PaneToolbar`'s `init` and thread it through to `PathBar`.

## Next-session inputs

- `Sources/UI/Toolbar/PaneToolbarViewModel.swift` — callback contract documented above.
- `Sources/UI/Toolbar/HistoryStack.swift` — `navigate(to:)` must be called for every pane
  navigation to keep history in sync.
- `Sources/UI/Toolbar/SearchDebouncer.swift` — `SleepFunction` typealias for test injection.
- `Sources/UI/Toolbar/PathBar.swift` — `maxVisible = 5` static threshold; `breadcrumbs`
  computed property is `internal` (not `public`).
- `Tests/UITests/ToolbarTests/` — 23 passing tests; do not regress them.

## Verification

All commands run from the worktree root.

```
swift build --target UIToolbar
```
→ `Build of target 'UIToolbar' complete!` — 0 warnings.

```
swift build -Xswiftc -warnings-as-errors
```
→ `Build complete!` — 0 warnings across entire package.

```
swift test --filter ToolbarTests
```
→ `Executed 23 tests, with 0 failures (0 unexpected)`.

```
swiftformat Sources/UI/Toolbar Tests/UITests/ToolbarTests --lint
```
→ `0/11 files require formatting`.

```
swiftlint lint --strict Sources/UI/Toolbar
```
→ `Found 0 violations, 0 serious in 304 files`.
