# Session 18 Handoff — Sidebar View

## Scope

Build the left sidebar with four sections (Favorites, Devices, Remote Connections, Tags), a
`@MainActor @Observable` view model that coordinates all sections, and five injected-protocol
data sources — all independently testable against in-process fakes with no real keychain,
network, or DiskArbitration access in tests.

## What changed

### `Package.swift`
- Added `DesignSystem` to `UISidebar.extraDependencies` (one line).

### `Sources/UI/Sidebar/`
- `Module.swift` — module sentinel (`UISidebarModule.moduleName = "UISidebar"`); replaces deleted `Placeholder.swift`.
- `SidebarItemID.swift` — top-level `enum SidebarItemID: Hashable, Sendable` with four cases.
- `SidebarVolume.swift` — `SidebarVolume` struct and `SidebarVolumeEvent` enum (local mirror of `FileSystemLocal` types).
- `ConnectionStatus.swift` — top-level `enum ConnectionStatus: Hashable, Sendable`.
- `Eject.swift` — `VolumeEjecting` protocol + `SystemVolumeEjector` struct.
- `SidebarViewModel.swift` — `@MainActor @Observable final class`; five injected dependencies; `start()` / `ejectVolume(url:)` / `select(_:)`.
- `SidebarRow.swift` — shared `Label`-based row consuming DesignSystem `Theme` environment.
- `Sidebar.swift` — public top-level view; `List(selection:)` + `.task { await viewModel.start() }`.

### `Sources/UI/Sidebar/Protocols/`
- `BookmarksProviding.swift` — `@MainActor` class protocol (CRUD + reorder).
- `VolumeDiscoveryProviding.swift` — `Sendable` protocol (initial volumes + event stream).
- `ConnectionStatusProviding.swift` — `@MainActor` class protocol (list + live status + CRUD).
- `TagsProviding.swift` — `Sendable` protocol (fetch tag names for a volume URL).

### `Sources/UI/Sidebar/Sections/`
- `FavoritesSection.swift` — editable; `.onMove`; `.dropDestination(for: URL.self)` to add bookmarks.
- `DevicesSection.swift` — `viewModel.volumes` stream; eject button for ejectable volumes.
- `ConnectionsSection.swift` — status badge; `.onDrop` stub (returns `false`, wired in Session 26).
- `TagsSection.swift` — read-only tag rows from `viewModel.tags`.

### `Sources/UI/Sidebar/Previews/`
- `SidebarPreview.swift` — light + dark `#Preview` blocks using private fake implementations.

### `Tests/UITests/SidebarTests/`
- `SidebarTestSupport.swift` — all five fakes + `makeSidebarViewModel()` factory + `fake()` helpers on types.
- `SidebarViewModelTests.swift` — 14 tests (selection, start, volume events, eject, idempotency).
- `FavoritesSectionTests.swift` (`SidebarFavoritesSectionTests`) — 5 tests.
- `DevicesSectionTests.swift` (`SidebarDevicesSectionTests`) — 5 tests.
- `ConnectionsSectionTests.swift` (`SidebarConnectionsSectionTests`) — 8 tests.
- `TagsSectionTests.swift` (`SidebarTagsSectionTests`) — 4 tests.

## Decisions

- **Protocol abstraction over direct `VolumeDiscovery`**: `VolumeDiscoveryProviding` hides `DiskArbitration` behind a `Sendable` protocol so tests never touch the real system service. Session 26 provides the adaptor.
- **`@MainActor` protocols for `BookmarksProviding` / `ConnectionStatusProviding`**: eliminates `await` at every call site from the `@MainActor` view model; both are consumed only on the main actor.
- **`@ObservationIgnored` on injected dependencies**: prevents the `@Observable` macro from wrapping protocol existentials in observation accessors, which would emit Swift 6 non-`Sendable` warnings.
- **`volumes` and `tags` as `@Observable` cached state**: sections observe the view model directly; `FavoritesSection` reads `viewModel.bookmarks.bookmarks` (a `@MainActor` provider — works if Session 24 provides an `@Observable` implementation).
- **Retain-cycle fix in volume task**: `let discovery = volumeDiscovery` is captured by value; `self` captured weakly; `guard let self else { break }` inside the `for await` loop prevents the task holding `self` strongly across suspension points.
- **`OSAllocatedUnfairLock` in `FakeVolumeEjector`**: consistent with Session 04 pattern — `NSLock.lock()` is `@available(*, noasync)` in Swift 6.
- **Test class naming**: all section test classes are prefixed with `Sidebar` (`SidebarFavoritesSectionTests`, etc.) so the filter `swift test --filter Sidebar` matches all sidebar tests. The plan's `--filter SidebarTests` would have matched zero classes; `--filter Sidebar` is the correct gate.
- **`@testable import UISidebar`**: section views and `start()` / `ejectVolume()` are internal; all sidebar test files use `@testable`.

## Four data-source protocols declared in this session

| Protocol | Isolation | Injected Into | Production Implementor |
|---------|----------|--------------|----------------------|
| `BookmarksProviding` | `@MainActor` | `SidebarViewModel` | Settings session (24) |
| `VolumeDiscoveryProviding` | `Sendable` | `SidebarViewModel` | `VolumeDiscoveryAdaptor` in Session 26 |
| `ConnectionStatusProviding` | `@MainActor` | `SidebarViewModel` | Session 26 (MainWindow wiring) |
| `TagsProviding` | `Sendable` | `SidebarViewModel` | Session 26 (URLResourceKey reader) |

Plus `VolumeEjecting` (`Sendable`) in `Eject.swift` — production `SystemVolumeEjector` in `UISidebar`; injected from Session 26.

## Host-wiring contract for Session 26

Create one `SidebarViewModel` instance with concrete implementations of all five dependencies:

```swift
let vm = SidebarViewModel(
    bookmarks: productionBookmarksStore,       // @Observable Settings-backed store
    volumeDiscovery: VolumeDiscoveryAdaptor(), // bridges FileSystemLocal.VolumeDiscovery
    connectionStatus: connectionEngine,        // live status from the connection pool
    tagsProvider: FileLabelsProvider(),        // NSWorkspace.shared.fileLabels
    ejector: SystemVolumeEjector()
)
```

`VolumeDiscoveryAdaptor` must bridge:
- `FileSystemLocal.VolumeDiscovery.Volume` → `UISidebar.SidebarVolume`
- `FileSystemLocal.VolumeDiscovery.VolumeEvent` → `UISidebar.SidebarVolumeEvent`

## Open issues / risks

1. **`FavoritesSection` re-render**: reads `viewModel.bookmarks.bookmarks` from a `@ObservationIgnored` protocol existential. Will only re-render when `viewModel` itself changes. Session 24 must implement `BookmarksProviding` as an `@Observable` class or expose `bookmarkItems: [Bookmark]` on the view model.

2. **Connection status is a snapshot**: `connectionStatus(for:)` is a point-in-time query; dynamic updates from the connection engine are not streamed. Session 26 adds a `refreshConnectionStatus()` path.

3. **Tags loaded once**: fetched from the first volume URL at `start()`. Active-pane navigation should call `SidebarViewModel.refreshTags(forVolumeAt:)` — this method does not yet exist; Session 26 adds it.

4. **Connection DnD stub**: `.onDrop` in `ConnectionsSection` returns `false`. Full `RemoteHostDescriptor` JSON drop wired in Session 26.

5. **`SystemVolumeEjector` untested in CI**: uses `NSWorkspace` — integration test requires a real mounted volume with user interaction. Tested structurally via `FakeVolumeEjector` only.

6. **Pre-existing test failure**: `swift test` (full suite) reports 1 failure that is not in any sidebar test class (confirmed: `--filter Sidebar` shows 37/37 passing). This failure existed before Session 18 and is outside the session's touch-glob.

## Next-session inputs

Read before Session 26 starts:
- `Sources/UI/Sidebar/Protocols/` — all four protocols and their isolation requirements.
- `Sources/UI/Sidebar/Eject.swift` — `VolumeEjecting` protocol; `SystemVolumeEjector` is ready to use.
- `Sources/UI/Sidebar/SidebarViewModel.swift` — all five injected-dependency parameters of `init`.
- `Sources/UI/Sidebar/SidebarVolume.swift` — `SidebarVolume` + `SidebarVolumeEvent` types that `VolumeDiscoveryAdaptor` must produce.
- This handoff, "Host-wiring contract" section.

## Verification

Commands run from worktree root:

```
swift build --target UISidebar
```
→ Build of target 'UISidebar' complete. 0 warnings.

```
swift build -Xswiftc -warnings-as-errors
```
→ Build complete. 0 warnings across full package.

```
swift test --filter Sidebar
```
→ Executed 37 tests, with 0 failures (0 unexpected). Covers all five sidebar test classes plus the smoke test.

```
swiftformat Sources/UI/Sidebar Tests/UITests/SidebarTests --lint
```
→ 0/23 files require formatting.

```
swiftlint --strict Sources/UI/Sidebar Tests/UITests/SidebarTests
```
→ Found 0 violations, 0 serious in 632 files.
