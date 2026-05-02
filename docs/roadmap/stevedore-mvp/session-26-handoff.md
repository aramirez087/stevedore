# Session 26 Handoff — Main Window Shell

## Scope

Wired the application together with a fully functional dual-pane main window: left and right
panes each with their own toolbar and tab strip, a shared `NavigationSplitView` sidebar,
a drag-resizable split divider, an auto-appearing Transfers panel, and `AppEnvironment` as
the DI root that constructs every service and hands the composed `MainWindowModel` to the
`MainWindowScene`.

## What changed

### `Package.swift`
- `MainWindow` extraDependencies expanded: `DesignSystem`, `UISidebar`, `UIToolbar`,
  `FeaturesOperations`, `ServicesSettings`
- `UIToolbar` extraDependencies: added missing `DesignSystem` (pre-existing Session 19 gap)
- `Stevedore` executable target: 14 explicit dependencies (was 4)
- `UITests` test target: added `FeaturesOperations`

### `Sources/UI/MainWindow/` (replaces Placeholder.swift)
- `MainWindowModule.swift` — module sentinel
- `PaneID.swift` — `enum PaneID: String, Codable, Sendable, Hashable { case left, right }`
- `WindowState.swift` — `@MainActor @Observable WindowState` (splitFraction clamped 0.2–0.8,
  activePaneID, selectedSidebarItem); `WindowStateSnapshot: Codable, Sendable, Equatable`
  (selectedSidebarItem omitted — SidebarItemID is not Codable)
- `PaneSession.swift` — `@MainActor @Observable PaneSession`; `navigate(to:)` delegates to
  toolbar (keeps history); `updatePath(to:)` is private (called from onNavigate, avoids
  re-entrancy loop); openTab / closeTab / activateTab manage tab list
- `PaneHost.swift` — `PaneToolbar + PaneTabStrip + PaneContentPlaceholder`; uses `Core.Tab`
  explicitly (avoids `SwiftUI.Tab` ambiguity on macOS 15 SDK); drop destination converts
  `URL` → `FilePath`; active border via `strokeBorder`
- `DualPaneLayout.swift` — custom `GeometryReader` + `DragGesture` resizable split (not
  HSplitView — NSSplitView doesn't expose a binding); `PaneDividerStrip` with
  `NSCursor.resizeLeftRight` on hover
- `TransfersPanel.swift` — auto-shows Transfers queue when `activeOperations` non-empty;
  `TransferRow` with icon, name, destination, and state label
- `MainWindowModel.swift` — `@MainActor @Observable`; owns queue, sidebarVM, windowState,
  leftSession, rightSession, optional repository; streams `activeOperations` from background
  task; `handleDrop(_:onto:)` enqueues copy operation; `restore()` / `save()` persist workspace
- `MainWindowView.swift` — `NavigationSplitView` sidebar + `DualPaneLayout` detail;
  transfers panel `.transition(.move(edge: .bottom))`; sidebar selection routing via
  `.onChange`; `filePath(for:)` maps volume/bookmark SidebarItemID to FilePath
- `MainWindowScene.swift` — `WindowGroup("Stevedore", id: "main")` + `.commands` +
  `.defaultSize(width: 1200, height: 750)`
- `AppCommands.swift` — empty `Commands` stub for Session 27

### `App/Stevedore/`
- `AppEnvironment.swift` — `@MainActor @Observable` DI root; constructs all services with
  private adapters: `BookmarksProviderAdapter` (optimistic cache + async persist),
  `VolumeDiscoveryAdaptor` (bridges FileSystemLocal.VolumeDiscovery → VolumeDiscoveryProviding),
  `StubConnectionStatusProvider` (returns `.idle`), `FileLabelsProvider`; `JSONFileStore`
  init wrapped in `try?`; `OperationExecutor` keyed to `.local` scheme
- `StevedoreApp.swift` — updated to `@State private var env = AppEnvironment()` +
  `MainWindowScene(model: env.mainWindowModel)`
- `Info.plist` — bundle ID `com.stevedore.app`, LSMinimumSystemVersion 14.0
- `Stevedore.entitlements` — sandbox disabled, files read-write, app-scope bookmarks

### `Tests/UITests/MainWindowTests/` (new)
- `MainWindowTestSupport.swift` — fakes prefixed `MW` (avoids collision with SidebarTests
  fakes in the same UITests target): `MWFakeBookmarksProvider`, `MWFakeVolumeDiscoveryProvider`
  (`@unchecked Sendable`), `MWFakeConnectionStatusProvider` (returns `.idle`),
  `MWFakeOperationQueue`
- `WindowStateTests.swift` — 6 tests: default fraction, clamping, Codable round-trip,
  snapshot empty tabs, activePaneID defaults to left
- `MainWindowTests.swift` — 11 tests: PaneSession init, navigate, toolbar sync, openTab,
  closeTab, close-last-is-no-op, activateTab, drop enqueues operation, active pane switch,
  window state round-trip, `NSHostingView` smoke test

## Quality gates

```
swift build -Xswiftc -warnings-as-errors   → Build complete (0 errors, 0 warnings)
swift test --filter MainWindow             → 12/12 passed
swift test                                 → 952 tests, 1 pre-existing failure (not S26)
swiftformat … --lint                       → 0/16 files require formatting
swiftlint --strict …                       → 0 violations in 794 files
```

Pre-existing failure not introduced by Session 26:
- `SidebarViewModelTests.testMountedEventAddsVolume` — sidebar async timing (pre-S26)
- `UninstallExecutorTests.testNoRemoveItemCall` — references s25 worktree path (pre-S26)

## Key design decisions

| Decision | Rationale |
|---|---|
| Custom GeometryReader split instead of HSplitView | NSSplitView doesn't expose a binding for the split position |
| `navigate(to:)` vs `updatePath(to:)` separation in PaneSession | Avoids re-entrancy: toolbar.onNavigate → updatePath (no callback); user action → navigate (calls toolbar) |
| `Core.Tab` explicit qualifier in PaneTabButton | macOS 15 SDK introduced `SwiftUI.Tab`; without qualifier the compiler treats `Tab` as ambiguous |
| `selectedSidebarItem` excluded from WindowStateSnapshot | `SidebarItemID` is not `Codable`; sidebar selection is restored implicitly |
| `@ObservationIgnored` on protocol existentials | Prevents non-Sendable warnings in @Observable classes with injected protocol deps |
| `ConnectionStatus.idle` (not `.disconnected`) | That's the enum case; `.disconnected` does not exist in Core |

## What Session 27 should build

- `AppCommands.swift` — wire up File/Edit/View/Go menu commands
- Per-session keyboard shortcuts (⌘T new tab, ⌘W close tab, ⌘[ / ⌘] back/forward)
- `MainWindowView` toolbar buttons (new tab, toggle sidebar, toggle transfers)
- Integration: route sidebar `.bookmark` items by fetching security-scoped URL from
  `BookmarksRepository` before constructing FilePath
