# Session 24 Handoff — Settings UI

## Scope

Implement the macOS-standard Settings window for Stevedore with four tabs (General, Appearance,
File Display, Advanced). Each tab reads and writes through the `SettingsStore` protocol via a
new `SettingBinding<T>` bridge class. Nine new `Setting` constants were added to the catalog.
All new behaviour is covered by tests that use `InMemorySettingsStore` exclusively — zero
filesystem I/O.

## What changed

### `Package.swift`
- Added `DesignSystem` and `ServicesSettings` as explicit dependencies of `UISettingsUI`.

### `Sources/Services/Settings/Settings+Catalog.swift`
- Added 9 new `Setting` constants: `startupBehavior`, `defaultTerminalApp`, `accentColor`,
  `density`, `dateFormat`, `logLevel`, `logRingBufferSize`, `conflictPolicy`,
  `transferConcurrencyCap`.
- Updated `allKeys` array to include all 24 keys.

### `Sources/UI/SettingsUI/Bindings/SettingBinding.swift` — new
- `@Observable @MainActor public final class SettingBinding<T: Codable & Sendable & Equatable>`.
- Bridges `Setting<T>` → `AsyncStream<T>` → `@Observable var value: T` → SwiftUI `Binding<T>`.
- `start()` / `stop()` lifecycle hooks for `.task` / `.onDisappear`.

### `Sources/UI/SettingsUI/SettingsScene.swift` — new
- `public struct SettingsScene: View` — content view for the `SwiftUI.Settings` scene.
- `TabView` with four tabs; `minWidth: 480, minHeight: 320`.

### `Sources/UI/SettingsUI/Tabs/GeneralTab.swift` — new
### `Sources/UI/SettingsUI/Tabs/AppearanceTab.swift` — new
### `Sources/UI/SettingsUI/Tabs/FileDisplayTab.swift` — new
### `Sources/UI/SettingsUI/Tabs/AdvancedTab.swift` — new
- Each tab is `@MainActor struct … : View` using `@State var: SettingBinding<T>` per control.
- `Form { Section { … } }` with `.formStyle(.grouped)`.

### `Tests/ServicesTests/SettingsTests/SettingsCatalogTests.swift`
- Updated `testAllKeysCoverEveryStaticSetting` count guard: 15 → 24.

### `Tests/UITests/SettingsUITests/SettingBindingTests.swift` — new (7 tests)
### `Tests/UITests/SettingsUITests/SettingsSceneTests.swift` — new (5 tests)

## Control-to-Setting key mapping

| Tab | Control | Setting key | Type |
|-----|---------|------------|------|
| General | Startup picker | `stevedore.startupBehavior` | `String` |
| General | Editor Command text field | `stevedore.defaultEditorCommand` | `String` |
| General | Terminal App text field | `stevedore.defaultTerminalApp` | `String` |
| General | Enable Dual Pane toggle | `stevedore.dualPaneEnabled` | `Bool` |
| Appearance | Appearance picker | `stevedore.theme` | `String` |
| Appearance | Accent Color picker | `stevedore.accentColor` | `String` |
| Appearance | Density picker | `stevedore.density` | `String` |
| File Display | Show Hidden Files toggle | `stevedore.showHiddenFiles` | `Bool` |
| File Display | File Size Display picker | `stevedore.byteSizeMode` | `String` |
| File Display | Date Format picker | `stevedore.dateFormat` | `String` |
| File Display | Sort By picker | `stevedore.sortOrder` | `String` |
| File Display | Ascending toggle | `stevedore.sortAscending` | `Bool` |
| Advanced | Log Level picker | `stevedore.logLevel` | `String` |
| Advanced | Log Buffer Size stepper | `stevedore.logRingBufferSize` | `Int` |
| Advanced | Conflict Policy picker | `stevedore.conflictPolicy` | `String` |
| Advanced | Max Concurrent Transfers stepper | `stevedore.transferConcurrencyCap` | `Int` |

## Decisions

- **`SettingBinding` as `@Observable @MainActor final class`**: A struct cannot hold a
  cancellable `Task` while being `@State`. `@Observable` provides automatic SwiftUI
  invalidation when `value` changes; `@MainActor` keeps all mutations on the main thread.
- **`@ObservationIgnored` on `setting`, `store`, `observationTask`**: Suppresses unnecessary
  observation tracking on properties that are either immutable or not consumed by views.
- **Immediate write on change**: `binding.set` fires `store.set` in a fire-and-forget `Task`;
  no Apply/Cancel buttons (macOS Settings convention).
- **`--self insert` compliance**: The project's `.swiftformat` config requires explicit `self.`
  for all property accesses. SwiftFormat auto-corrected all files after initial write.
- **`Setting<Int>` for buffer/concurrency caps**: `Stepper` binds directly to `Binding<Int>`;
  using `Double` would store/read wrong values.
- **Test filter note**: XCTest class names are `SettingBindingTests` and `SettingsSceneTests`.
  Use `--filter "SettingBinding|SettingsScene"` (not `--filter SettingsUITests`).

## Open issues / risks

1. **Theme override on the Settings window itself** (exit criterion): The `AppearanceTab`
   writes `stevedore.theme` but the theme override is not wired to the window's
   `colorScheme` in this session. Session 26 (Main Window Shell) owns the composition root
   where the `Settings` scene is created; wiring the live theme there is straightforward.
2. **`testStopCancelsObservation` timing**: The test relies on cooperative Task cancellation.
   If test infrastructure is heavily loaded, a stale emission could theoretically arrive
   before the cancellation check. Observed zero flakes across multiple runs.
3. **`InMemorySettingsStore.observe` registration+snapshot race** (known, from Session 07):
   A `store.set` between stream registration and first-emit may produce a stale snapshot.
   Not exercised by current tests; benign since the next write re-emits.

## Next-session inputs

- `Sources/UI/SettingsUI/SettingsScene.swift` — inject `SettingsScene(store:)` inside
  a `SwiftUI.Settings { }` scene in the app's composition root (Session 26).
- `Sources/Services/Settings/Settings+Catalog.swift` — 24 total keys; all keys unique and
  prefixed `stevedore.`.
- `Sources/UI/SettingsUI/Bindings/SettingBinding.swift` — `SettingBinding<T>` is public;
  can be used by other UI sessions if they need observable store-backed bindings.

## Verification

All commands run from the worktree root.

```
swift build --target UISettingsUI
```
→ `Build of target: 'UISettingsUI' complete!` 0 warnings.

```
swift build --target UISettingsUI \
    -Xswiftc -strict-concurrency=complete \
    -Xswiftc -warnings-as-errors
```
→ `Build of target: 'UISettingsUI' complete!` 0 warnings.

```
swift test --filter "SettingBinding|SettingsScene|UISettingsUISmoke|SettingsCatalog"
```
→ Executed 19 tests, with 0 failures (0 unexpected).
  - `SettingBindingTests`: 7 tests
  - `SettingsSceneTests`: 5 tests
  - `UISettingsUISmokeTests`: 1 test
  - `SettingsCatalogTests`: 6 tests

```
swiftformat Sources/UI/SettingsUI Tests/UITests/SettingsUITests --lint
```
→ `0/9 files require formatting.`

```
swiftlint --strict Sources/UI/SettingsUI
```
→ `Found 0 violations, 0 serious in 334 files.`
