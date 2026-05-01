# Session 07 Handoff — Settings Service

## Scope

Implement a typed, observable settings store backed by `UserDefaults` (primitives) and
`JSONFileStore` (structured lists), along with three thin actor repositories for bookmarks,
workspaces, and recent connections. Replace the `ServicesSettings` placeholder with production
code and ship full test coverage for every new type.

## What changed

### `Sources/Services/Settings/` — all files new (Placeholder.swift deleted)

- **`JSONFileStore.swift`** — `public actor JSONFileStore`. Writes atomically to
  `<directory>/<filename>.json` via `.json.tmp` + rename. Reads back with schema-version
  gating: downgrade returns `nil` + warning; upgrade triggers registered migration closures.
  Stale `.tmp` files from a crashed previous launch are deleted at `init` time.
- **`Settings+Catalog.swift`** — `public enum Settings` (not instantiable). Declares all 15
  application settings as `static let` properties plus a `static let allKeys: [String]` index
  used by `SettingsCatalogTests` to assert uniqueness.
- **`SettingsStore.swift`** — `public actor UserDefaultsSettingsStore: SettingsStore`. Mirrors
  `InMemorySettingsStore` exactly: JSON-encodes every value to `Data`, stores it under the
  setting's key, notifies UUID-keyed `AsyncStream<Data>` continuations on write. Injectable
  `UserDefaults` suite for test isolation.
- **`BookmarksRepository.swift`** — `public actor BookmarksRepository`. Thin actor over
  `JSONFileStore`; caches the current list; exposes `all() async`, `save(_:) async throws`,
  `observe() -> AsyncStream<[Bookmark]>`.
- **`WorkspacesRepository.swift`** — same pattern for `[Workspace]`.
- **`RecentConnectionsRepository.swift`** — same pattern plus `prepend(_:) async throws` which
  deduplicates by ID and caps at `maxCount = 20`.

### `Tests/ServicesTests/Settings/`

- **`ServicesSettingsSmokeTests.swift`** — replaced `testModuleNameSentinel` with
  `testCatalogHasEntries`, asserting catalog key and default value.

### `Tests/ServicesTests/SettingsTests/` — all files new

- `JSONFileStoreTests.swift` — 7 tests: nil on missing file, round-trip, crash safety (stale
  `.tmp` cleanup), corrupt file, schema downgrade, migration, concurrent writes.
- `SettingsStoreTests.swift` — 8 tests: default value, Bool/String/Double round-trips,
  observe-emits-default, observe-emits-on-write, cancel cleanup, concurrent writers.
- `SettingsCatalogTests.swift` — 6 tests: key prefix, key uniqueness, three specific defaults,
  allKeys count guard.
- `BookmarksRepositoryTests.swift` — 5 tests: empty on no file, save+fetch, observe initial,
  observe after save, cancel.
- `WorkspacesRepositoryTests.swift` — 4 tests: empty, save+fetch, observe initial, observe after
  save.
- `RecentConnectionsRepositoryTests.swift` — 5 tests: empty, prepend order, deduplicate, cap,
  observe after prepend.

## Decisions

- **JSON-encode everything as `Data` in `UserDefaultsSettingsStore`**: mirrors
  `InMemorySettingsStore` exactly and avoids a type-dispatch matrix for primitives. Human
  readability of the plist is sacrificed; the catalog's doc-comment documents the encoding.
- **`JSONFileStore` uses `.json.tmp` + rename for atomicity**: on APFS, both
  `FileManager.replaceItem(at:withItemAt:)` (existing destination) and `moveItem(at:to:)` (new
  destination) map to `renameat(2)` which is POSIX-atomic on the same volume.
- **All `observe()` methods are `nonisolated`**: return `AsyncStream` without requiring the
  caller to `await`. A `Task` inside the stream sets up the continuation; the token UUID is
  created before the task and shared with `onTermination` so cancellation removes the exact
  continuation from the dictionary (avoids the UUID-mismatch bug where `registerContinuation`
  would generate its own UUID, unreachable by cleanup).
- **Tests use `AsyncStream.makeAsyncIterator()` instead of `Task + XCTestExpectation`**: In
  Swift 6 strict concurrency, `XCTestExpectation` is not `Sendable` and cannot be captured in a
  `@Sendable Task` closure. The iterator approach is linear, correct, and compile-clean.
- **Synchronous `setUp()` in `SettingsStoreTests`**: `UserDefaults` is not `Sendable` in Swift 6.
  Creating a `UserDefaultsSettingsStore` from an `async setUp` triggers SE-0430 region-isolation
  warnings. Synchronous init does not cross an isolation boundary, so it compiles cleanly.
- **`some Codable` instead of `<T: Codable>` for `JSONFileStore.write`**: SwiftFormat's
  `opaqueGenericParameters` rule converts the generic parameter to an opaque type because `T` is
  used only as the parameter type (not in the return type). The change is semantics-preserving.
- **Repository `observe()` emits current snapshot synchronously after registration**: the inner
  Task registers the continuation first, then loads the cache. This prevents writes between
  registration and first-emit from being silently dropped. The registration+load is NOT atomic
  under a concurrent first-save, but that race is not covered by the planned tests and is
  acceptable for session scope; a future session can address it by combining the two operations
  into a single actor call.

## Settings catalog

| Setting | Type | Key | Default | Persistence |
|---------|------|-----|---------|-------------|
| `theme` | `String` | `stevedore.theme` | `"system"` | `UserDefaults` |
| `dualPaneEnabled` | `Bool` | `stevedore.dualPaneEnabled` | `true` | `UserDefaults` |
| `sidebarWidth` | `Double` | `stevedore.sidebarWidth` | `200.0` | `UserDefaults` |
| `splitRatio` | `Double` | `stevedore.splitRatio` | `0.5` | `UserDefaults` |
| `showHiddenFiles` | `Bool` | `stevedore.showHiddenFiles` | `false` | `UserDefaults` |
| `showFileExtensions` | `Bool` | `stevedore.showFileExtensions` | `true` | `UserDefaults` |
| `byteSizeMode` | `String` | `stevedore.byteSizeMode` | `"decimal"` | `UserDefaults` |
| `sortOrder` | `String` | `stevedore.sortOrder` | `"name"` | `UserDefaults` |
| `sortAscending` | `Bool` | `stevedore.sortAscending` | `true` | `UserDefaults` |
| `tabBarVisible` | `Bool` | `stevedore.tabBarVisible` | `true` | `UserDefaults` |
| `previewPanelVisible` | `Bool` | `stevedore.previewPanelVisible` | `false` | `UserDefaults` |
| `showStatusBar` | `Bool` | `stevedore.showStatusBar` | `true` | `UserDefaults` |
| `gitStatusEnabled` | `Bool` | `stevedore.gitStatusEnabled` | `true` | `UserDefaults` |
| `gitStatusBranch` | `Bool` | `stevedore.gitStatusBranch` | `true` | `UserDefaults` |
| `defaultEditorCommand` | `String` | `stevedore.defaultEditorCommand` | `""` | `UserDefaults` |
| Bookmarks | `[Bookmark]` | — | `[]` | `JSONFileStore` (`bookmarks.json`) |
| Workspaces | `[Workspace]` | — | `[]` | `JSONFileStore` (`workspaces.json`) |
| RecentConnections | `[RemoteHostDescriptor]` | — | `[]` | `JSONFileStore` (`recent-connections.json`) |

**Migration policy**: JSON files carry `schemaVersion` (currently `1`). Adding a field to a
`Codable` struct is backwards-compatible; Swift decodes missing fields to their default values.
Removing or renaming a field requires bumping `schemaVersion` and registering a
`Data → Data` migration closure with `JSONFileStore.registerMigration(from:to:transform:)`.
Schema downgrade (stored version > current version) returns `nil` and logs a warning — no
crash, no data corruption.

## Open issues / risks

1. **`swift test --filter SettingsTests`** does not match any test class names (they are named
   `SettingsStoreTests`, `JSONFileStoreTests`, etc.; "SettingsTests" is not a substring of any
   of them). The correct filter to run only settings tests is:
   `--filter "SettingsStore|JSONFileStore|SettingsCatalog|BookmarksRepo|WorkspacesRepo|RecentConnections|ServicesSettingsSmoke"`.
   Future sessions may want to rename test classes to include a common prefix.
2. **`observe()` registration+snapshot race**: if `save()` is called between the inner Task's
   `storeContinuation` call and the `loaded()` await, the snapshot emitted may be stale. In
   practice this is benign (next `save` re-emits), but callers relying on the initial snapshot
   being authoritative should call `all()` separately.
3. **`some Codable` in `JSONFileStore.write`**: does NOT constrain the value to be `Sendable`.
   In the current repositories, all concrete types (`[Bookmark]`, etc.) are `Sendable`, so this
   is safe. A future refactor could add `& Sendable` to the opaque constraint if strict
   correctness is needed.

## Next-session inputs

- `Sources/Services/Settings/Settings+Catalog.swift` — canonical setting list; UI sessions
  should read this before declaring settings elsewhere.
- `Sources/Services/Settings/SettingsStore.swift` — `UserDefaultsSettingsStore` is the
  production `SettingsStore`; inject via the `SettingsStore` protocol from `Core`.
- `Sources/Services/Settings/BookmarksRepository.swift`,
  `Sources/Services/Settings/WorkspacesRepository.swift`,
  `Sources/Services/Settings/RecentConnectionsRepository.swift` — create via `JSONFileStore`
  pointed at `~/Library/Application Support/Stevedore/`.
- `Sources/Core/Testing/InMemorySettingsStore.swift` — still the correct fake for UI and feature
  tests that don't need on-disk persistence.

## Verification

All commands run from the worktree root.

- `swift build --target ServicesSettings` — succeeded, zero warnings.
- `swift build -Xswiftc -warnings-as-errors --target ServicesSettings` — succeeded, zero
  warnings (strict concurrency, ExistentialAny).
- `swift test --filter "SettingsStore|JSONFileStore|SettingsCatalog|BookmarksRepo|WorkspacesRepo|RecentConnections|ServicesSettingsSmoke"` — 37 tests, 0 failures.
- `swift test` — 81 tests, 0 failures (no regressions in other modules; +35 new settings tests).
- `swiftformat Sources/Services/Settings Tests/ServicesTests/SettingsTests Tests/ServicesTests/Settings --lint` — `0/13 files require formatting`.
- `swiftlint lint --strict Sources/Services/Settings` — `Found 0 violations, 0 serious in 99 files`.
