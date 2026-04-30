---
session: 18
title: "Sidebar View (Favorites, Devices, Connections)"
depends_on: [01, 02, 04, 06, 08]
touches:
  - Sources/UI/Sidebar/**
  - Tests/UITests/SidebarTests/**
parallel_safe: true
---

# Session 18: Sidebar View

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 04, 06, 08 artifacts. Read each handoff. Use `import Core`, `import DesignSystem`, `import FileSystemRemote`, `import ServicesCredentials`.

Mission
Build the left sidebar listing: Favorites (user-defined bookmarks), Devices (mounted local volumes), Remote Connections (saved hosts + active sessions), and Tags. Selection drives the active pane's path.

Repository anchors
- Sources/UI/Sidebar/Sidebar.swift (SwiftUI top-level)
- Sources/UI/Sidebar/SidebarViewModel.swift
- Sources/UI/Sidebar/Sections/FavoritesSection.swift
- Sources/UI/Sidebar/Sections/DevicesSection.swift
- Sources/UI/Sidebar/Sections/ConnectionsSection.swift
- Sources/UI/Sidebar/Sections/TagsSection.swift
- Sources/UI/Sidebar/SidebarRow.swift
- Sources/UI/Sidebar/Eject.swift (eject volumes)
- Tests/UITests/SidebarTests/*.swift

Tasks
1. `SidebarViewModel` is `@MainActor` and `@Observable`; receives data sources (Favorites, Volumes, Connections, Tags) via initializer injection — no global lookups. Exposes `selection: SidebarItemID?` and `select(_:)`.
2. Favorites section is editable: add/remove/reorder via context menu; reorder uses SwiftUI `.onMove`. The actual repository belongs to the Settings session — this view depends on a `BookmarksProviding` protocol it declares locally.
3. Devices section subscribes to the `VolumeDiscovery` async stream from `FileSystemLocal` and renders mounted volumes with eject affordance for ejectable disks.
4. Connections section lists saved `RemoteHostDescriptor`s and shows live status (connected/connecting/idle/error) for active sessions. Inject a `ConnectionStatusProviding` protocol.
5. Tags section lists Finder tags (read via `URLResourceKey.tagNamesKey`) — a small fixed list populated from the active local volume.
6. Drag-and-drop: drop a path onto Favorites to add a bookmark; drop a connection onto Connections to save it.
7. Tests: every section renders against fakes; selection callbacks fire with the right `SidebarItemID`; eject calls the injected ejector; favorites reordering is stable.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-18-handoff.md` describing the four data-source protocols this session declares and the host-wiring contract.

Quality gates
- `swift build --target UISidebar`
- `swift test --filter SidebarTests`
- `swiftformat --lint Sources/UI/Sidebar Tests/UITests/SidebarTests`
- `swiftlint --strict --path Sources/UI/Sidebar`

Exit criteria
- Sidebar compiles and tests pass with only in-process fakes — no real keychain or network access in tests.
- Each section is independently testable (its own preview, its own test class).
- Volume eject path triggers the injected `VolumeEjecting` collaborator and not `FileManager` directly.
```
