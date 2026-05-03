# Session 02 Handoff — Fix Back Navigation (Bug #054)

## Completed

Fixed bug #054: back navigation broken via toolbar, Go menu, and ⌘[ keyboard shortcut.

**Root cause confirmed**: `PaneCommandProxy` was registered with `.focusedValue` in `PaneHost.body`,
which only propagates to the Commands tree when keyboard focus is physically inside the PaneHost
subtree. After a sidebar click, double-click navigation, or first launch, SwiftUI focus sits
elsewhere, so `GoMenuCommands.proxy` resolved to `nil` and the Back/Forward menu items were
permanently disabled.

**Fix applied**: changed the emitter from `.focusedValue` to `.focusedSceneValue`. This makes the
proxy available throughout the window scene regardless of which element holds keyboard focus,
which is the correct semantic for menu-bar Commands. The view modifier `.focusedSceneValue` is
available on the macOS 26 SDK; the corresponding property wrapper `@FocusedSceneValue` was removed
from this SDK, so `GoMenuCommands` retains `@FocusedValue` — which can read values written by
`.focusedSceneValue` since both use the same `FocusedValues` storage.

Also added first-class navigation convenience methods to `PaneSession`, and cleaned up `buildProxy()`
to call those methods instead of reaching through the internal `toolbarViewModel` chain. The
`goHome()` method now uses `FileManager.default.homeDirectoryForCurrentUser` (not `NSHomeDirectory()`)
per operator rules.

## Changes

| File | Lines changed | What |
|---|---|---|
| `Sources/UI/MainWindow/PaneSession.swift` | 1–3, 42–73 | Added `import Foundation`; added `canGoBack`, `canGoForward`, `goBack()`, `goForward()`, `goUp()`, `goHome()`, `goToComputer()` convenience methods |
| `Sources/UI/MainWindow/PaneHost.swift` | 50, 62–79 | `.focusedValue` → `.focusedSceneValue`; simplified `buildProxy()` to use new `PaneSession` methods |
| `Sources/UI/Menus/Sections/GoMenu.swift` | 5 | (no net change — `@FocusedSceneValue` reverted to `@FocusedValue` after discovering macOS 26 SDK removed `FocusedSceneValue` property wrapper) |
| `Tests/UITests/MainWindowTests/MainWindowTests.swift` | 67–101 | Added 5 PaneSession navigation tests |

## Bugs Fixed

**Bug #054** — back navigation broken via toolbar, Go menu, and ⌘[ — **FIXED**.

The toolbar chevron already worked (it calls `viewModel` directly). The Go menu and ⌘[ were
broken because `proxy` resolved to nil. Changing to `.focusedSceneValue` ensures `proxy` is
non-nil whenever the window is key.

## SDK Discovery (important for future sessions)

`@FocusedSceneValue` (property wrapper) is **not present** in the macOS 26 SDK (Swift 6.2.3,
`arm64e-apple-macos.swiftinterface` confirmed 0 matches). The view modifier
`.focusedSceneValue(_:_:)` IS present. The correct pattern on macOS 26:

- **Emitter**: `.focusedSceneValue(\.key, value)` on the View
- **Consumer**: `@FocusedValue(\.key)` in Commands (reads scene-scoped values)

## Manual Testing

Manual UI testing was not performed (this is a worktree agent session without display access).
The fix is mechanically correct:
- `.focusedSceneValue` writes to scene-level `FocusedValues` regardless of keyboard focus
- `@FocusedValue` reads from `FocusedValues`; when the value is scene-scoped it is always present
- All three entry points (toolbar, Go menu, ⌘[) call the same `session.goBack()` path via the proxy

## Quality Gates

```
swift build          → Build complete! (27.29s) — 0 errors, 0 warnings
swift test --filter MainWindowTests  → 21 tests, 0 failures
swift test --filter PaneCommandProxy → 15 tests, 0 failures
```

## Next Inputs

Session 05 (CI gate) needs to know:
- `Sources/UI/MainWindow/PaneSession.swift` now has `import Foundation` — no new dependency issues
- `@FocusedSceneValue` property wrapper does NOT exist on macOS 26 SDK; do not attempt to use it
- `PaneSession` now exposes `canGoBack`, `canGoForward`, `goBack()`, `goForward()`, `goUp()`,
  `goHome()`, `goToComputer()` as first-class public API — subsequent sessions may use these

## Open Issues

- Manual UI test skipped (no display in worktree agent). Recommend running the Xcode app target
  and exercising toolbar back button, Go > Back, and ⌘[ after a double-click navigation.
- Bug #055 (home sidebar navigates to wrong path) and #056 (3+ second spinner) are not addressed
  in this session — they belong to subsequent epic sessions.
