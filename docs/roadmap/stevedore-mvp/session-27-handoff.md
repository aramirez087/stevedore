# Session 27 Handoff — Menu Commands & Keyboard Shortcuts

## Scope

Wired all seven menu-bar sections (File, Edit, View, Go, Connect, Tools, Window) to the active pane
and window via `PaneCommandProxy` / `WindowCommandProxy` injected through `FocusedValues`.
Added dialog presentation flags to `MainWindowModel`, built proxy construction in `PaneHost` and
`MainWindowView`, and delivered 25 tests covering shortcut uniqueness and proxy dispatch.

## What changed

### `Sources/UI/Menus/PaneCommandProxy.swift`
- Added explicit `public init(...)` with 29 parameters (Swift's synthesized memberwise init is
  `internal`; the public init is required for `PaneHost` in the `MainWindow` module to construct it).

### `Sources/UI/Menus/WindowCommandProxy.swift`
- Added explicit `public init(...)` for the same reason.

### `Sources/UI/MainWindow/MainWindowModel.swift`
- Added four `public var` dialog presentation flags after `activeOperations`:
  `showConnectDialog`, `showSyncDialog`, `showRenameDialog`, `showUninstallerDialog`.

### `Sources/UI/MainWindow/PaneHost.swift`
- Added `import UIMenus`.
- Added `.focusedValue(\.paneCommandProxy, self.isActive ? self.buildProxy() : nil)` modifier
  in `body` after `.dropDestination`.
- Added `private func buildProxy() -> PaneCommandProxy` that captures the pane session by value
  and constructs a fully-populated proxy. Navigation actions (goUp/goHome/goToComputer/goBack/
  goForward) are wired; file-op stubs (newFolder/newFile/open etc.) are `{}` pending UIPane
  (Session 16); tab management (openNewTab/closeActiveTab/nextTab/previousTab) is wired;
  openInTerminal calls `OpenInTerminal.launch(path:using:"")` with auto-detection fallback.

### `Sources/UI/MainWindow/MainWindowView.swift`
- Added `import UIMenus`.
- Added `.focusedValue(\.windowCommandProxy, self.buildWindowProxy())` modifier.
- Added four `.sheet(isPresented:)` modifiers driven by the model's dialog flags
  (placeholder `Text(...)` content — real dialog VMs need injected credentials from AppEnvironment).
- Added `private func buildWindowProxy() -> WindowCommandProxy`.

### `Tests/UITests/MenusTests/` (new directory, 4 files)
- `MenusTestSupport.swift` — `PaneCommandProxy.makeStub(...)` and `WindowCommandProxy.makeStub(...)`
  factory helpers with default-`{}` parameters.
- `ShortcutsTests.swift` — 5 tests: all shortcuts unique, no conflict between openInTerminal/
  reopenClosedTab, newTab/openInTerminal differ, goBack/nextTab differ, goForward/previousTab differ.
- `PaneCommandProxyTests.swift` — 15 tests: each navigation/tab closure invoked; isRemoteReadOnly
  and canGoBack/Forward reflect constructor values.
- `WindowCommandProxyTests.swift` — 5 tests: each dialog and focusSearch closure invoked.

## Complete Command / Shortcut Table

| Menu | Item | Shortcut | Action | Status |
|------|------|----------|--------|--------|
| File | New File | Cmd+N | `newFile()` | stub |
| File | New Folder | Cmd+Shift+N | `newFolder()` | stub |
| File | Open | Cmd+O | `open()` | stub |
| File | Open With… | — | `openWith()` | stub |
| File | Move to Trash | Cmd+Del | `moveToTrash()`; disabled on read-only remote | stub |
| File | Compress | — | `compress()` | stub |
| File | Decompress | — | `decompress()` | stub |
| Edit | Find… | Cmd+F | `focusSearch()` | stub |
| View | Show Hidden Files | Cmd+Shift+. | `toggleHiddenFiles()` | stub |
| View | Refresh | Cmd+R | `refresh()` | stub |
| View | Sort By → Name | — | `sortByName()` | stub |
| View | Sort By → Date Modified | — | `sortByDateModified()` | stub |
| View | Sort By → Size | — | `sortBySize()` | stub |
| View | Sort By → Kind | — | `sortByKind()` | stub |
| View | as List / Columns / Icons | — | disabled stubs | stub |
| Go | Up | Cmd+↑ | parent via `NSString.deletingLastPathComponent` | **wired** |
| Go | Back | Cmd+[ | `toolbarViewModel.goBack()`; disabled `!canGoBack` | **wired** |
| Go | Forward | Cmd+] | `toolbarViewModel.goForward()`; disabled `!canGoForward` | **wired** |
| Go | Home | Cmd+Shift+H | navigate to `NSHomeDirectory()` | **wired** |
| Go | Computer | — | navigate to `/` | **wired** |
| Go | Recent Folders | — | placeholder submenu | stub |
| Connect | Connect to Server… | Cmd+K | `showConnectDialog = true` | **wired** |
| Connect | Recent Connections | — | placeholder submenu | stub |
| Tools | Compare/Sync Folders… | — | `showSyncDialog = true` | **wired** |
| Tools | Multi-Rename… | — | `showRenameDialog = true` | **wired** |
| Tools | Application Uninstaller… | — | `showUninstallerDialog = true` | **wired** |
| Tools | Open in Terminal | Cmd+Shift+T | `OpenInTerminal.launch(path:using:"")` | **wired** |
| Window | New Tab | Cmd+T | `openTab(at: currentPath)` | **wired** |
| Window | Close Tab | Cmd+W | `closeTab(activeTabID)` | **wired** |
| Window | Reopen Closed Tab | Cmd+Shift+Z | stub | stub |
| Window | Next Tab | Cmd+Shift+] | index+1 `activateTab` | **wired** |
| Window | Previous Tab | Cmd+Shift+[ | index-1 `activateTab` | **wired** |

**Shortcut conflict resolved:** `reopenClosedTab` uses Cmd+Shift+Z (not Cmd+Shift+T) to avoid
collision with `openInTerminal` (Cmd+Shift+T). Verified by `ShortcutsTests.testAllShortcutsAreUnique`.

## Decisions

- **Explicit `public init` on both proxies.** Swift's synthesized memberwise init is `internal`;
  without an explicit public init, the `PaneHost` (in the `MainWindow` module) cannot construct
  a `PaneCommandProxy` (defined in `UIMenus`).
- **`function_parameter_count` suppression not needed.** SwiftLint's project config does not
  enable this rule at a severity that triggers on 29-parameter inits; the disable comments were
  superfluous and would fail `--strict`.
- **`buildProxy()` captures session by value (`let session = self.session`).** Avoids retaining
  `self` (PaneHost is a struct) in the closures and prevents any re-entrancy risk.
- **Dialog sheets use `Text(...)` placeholders.** Real dialog VMs (ConnectDialog, UninstallerSheet
  etc.) require injected credentials/providers only available at the `AppEnvironment` composition
  root. Full wiring is deferred to Session 28 (CI Gate).
- **`isRemoteReadOnly = scheme != .local` MVP heuristic.** Real per-provider write-capability
  checks deferred to UIPane (Session 16).

## Open issues / risks

1. **Pre-existing `SidebarViewModelTests.testMountedEventAddsVolume` flake** — async timing issue
   from Session 18; not related to this session.
2. **Pre-existing `UninstallExecutorTests.testNoRemoveItemCall` failure** — references a worktree
   path that doesn't exist in this branch; from Session 25.
3. **Dialog sheets are placeholders.** Session 28 should wire in `ConnectDialog`,
   `UninstallerSheet`, and the sync/rename dialog views from Sessions 21–23.
4. **File-op stubs** (`newFolder`, `newFile`, `open`, `moveToTrash`, etc.) are `{}` pending
   UIPane (Session 16) which provides the file list model and selection context.
5. **`openInTerminal` passes `""` as preferred bundle ID**, falling back to the first installed
   terminal in `knownBundleIDs`. Wiring to `Settings.defaultTerminalApp` deferred to Session 28.

## Next-session inputs

Session 28 (CI Gate) should read:
- `Sources/UI/MainWindow/MainWindowModel.swift` — four dialog bool flags added here.
- `Sources/UI/MainWindow/MainWindowView.swift` — dialog sheets with placeholder content.
- `Sources/UI/MainWindow/PaneHost.swift` — `buildProxy()` wired navigation + tab commands.
- `Sources/UI/Menus/Shortcuts.swift` — canonical shortcut registry; all shortcuts verified unique.
- `Tests/UITests/MenusTests/` — 25 new tests.

## Verification

```
swift build --target MainWindow -Xswiftc -warnings-as-errors
→ Build of target: 'MainWindow' complete! (22.90s) — 0 warnings

swift build -Xswiftc -warnings-as-errors
→ Build complete! (9.82s) — 0 warnings

swift test --filter "ShortcutsTests|PaneCommandProxyTests|WindowCommandProxyTests"
→ Executed 25 tests, with 0 failures (0 unexpected)

swift test (full suite)
→ Executed 977 tests, with 2 failures
  Both failures are pre-existing (SidebarViewModelTests flake + UninstallExecutor worktree path)

swiftformat Sources/UI/Menus Sources/UI/MainWindow/MainWindowModel.swift \
    Sources/UI/MainWindow/PaneHost.swift Sources/UI/MainWindow/MainWindowView.swift \
    Tests/UITests/MenusTests --lint
→ 0/19 files require formatting

swiftlint --strict Sources/UI/Menus Tests/UITests/MenusTests
→ Found 0 violations, 0 serious in 824 files
```
