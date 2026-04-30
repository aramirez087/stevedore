---
session: 07
title: "Settings & Preferences Service"
depends_on: [01]
touches:
  - Sources/Services/Settings/**
  - Tests/ServicesTests/SettingsTests/**
parallel_safe: true
---

# Session 07: Settings & Preferences Service

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01 artifacts. Read `docs/roadmap/stevedore-mvp/session-01-handoff.md`. The `SettingsStore` protocol is defined in `Sources/Core/Protocols`.

Mission
Provide a typed, observable settings store backed by `UserDefaults` and JSON files for non-trivial structures (workspaces, bookmarks, favorites, recent connections). Drive the Settings UI and persist app state across launches.

Repository anchors
- Sources/Services/Settings/SettingsStore.swift (concrete impl)
- Sources/Services/Settings/Setting.swift (typed key + default)
- Sources/Services/Settings/Settings+Catalog.swift (declarations of every app setting)
- Sources/Services/Settings/JSONFileStore.swift (atomic write, schema-versioned)
- Sources/Services/Settings/BookmarksRepository.swift
- Sources/Services/Settings/WorkspacesRepository.swift
- Sources/Services/Settings/RecentConnectionsRepository.swift
- Tests/ServicesTests/SettingsTests/*.swift

Tasks
1. `Setting<Value>` value type pairing a key, default, and codec. `SettingsStore` actor reads/writes via `UserDefaults.standard` for primitives and `JSONFileStore` for structured types.
2. `Settings+Catalog.swift` declares every setting with its key and default — this is the canonical list. Examples: theme, dual-pane layout, hidden-file visibility, byte-size mode, default editor command.
3. `JSONFileStore` writes atomically to `Application Support/Stevedore/<file>.json`, with a `schemaVersion` field; future sessions can register migrations. Reads return defaults on missing/corrupt files (logged at warning level).
4. Repositories are thin actors over the JSON store: `BookmarksRepository`, `WorkspacesRepository`, `RecentConnectionsRepository`. Each exposes async stream of changes for live UI binding.
5. Provide `AsyncStream` change publisher for any `Setting` so views can update reactively. Backed by `NotificationCenter` under the hood.
6. Tests: round-trip every setting, atomic-write crash safety (write half a file, reopen, observe defaults restored), schema-version up/down assertions, observability test ensuring streams emit on writes.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-07-handoff.md` listing every declared setting, its default, where it persists, and the migration policy.

Quality gates
- `swift build --target ServicesSettings`
- `swift test --filter SettingsTests`
- `swiftformat --lint Sources/Services/Settings Tests/ServicesTests/SettingsTests`
- `swiftlint --strict --path Sources/Services/Settings`

Exit criteria
- Settings catalog is the single source of truth — adding a setting elsewhere triggers a compile error.
- Concurrent writers do not corrupt JSON files under parallel `Task` tests.
- Settings observation streams cancel cleanly when the consuming Task is cancelled.
```
