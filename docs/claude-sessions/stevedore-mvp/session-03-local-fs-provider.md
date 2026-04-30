---
session: 03
title: "Local Filesystem Provider"
depends_on: [01]
touches:
  - Sources/FileSystem/Local/**
  - Tests/FileSystemTests/LocalTests/**
parallel_safe: true
---

# Session 03: Local Filesystem Provider

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01 artifacts. Read `docs/roadmap/stevedore-mvp/session-01-handoff.md`. Implement the protocols defined in `Sources/Core/Protocols`; do not modify Core.

Mission
Implement the `FileSystemProvider` for the local Mac filesystem — directory enumeration, attribute reading, file ops (copy/move/delete/rename/mkdir/symlink), volume discovery, change watching — all using `FileManager`, `URLResourceValues`, `DispatchSource`/`FSEvents`, and async/await.

Repository anchors
- Sources/FileSystem/Local/LocalFileSystemProvider.swift
- Sources/FileSystem/Local/LocalDirectoryEnumerator.swift
- Sources/FileSystem/Local/LocalFileOperations.swift
- Sources/FileSystem/Local/VolumeDiscovery.swift
- Sources/FileSystem/Local/FSEventsWatcher.swift
- Sources/FileSystem/Local/Sandbox/SecurityScopedBookmarks.swift
- Tests/FileSystemTests/LocalTests/*.swift

Tasks
1. `LocalFileSystemProvider`: actor conforming to `FileSystemProvider`. Async enumeration yields `FileItem` lazily; honors `.skipsHiddenFiles` toggle.
2. Read `URLResourceValues` for size, modification date, kind, isPackage, isSymlink, fileResourceType, ownership/permissions. Map to `FileAttributes`.
3. File ops: copy, move, hard-link, symlink, trash (via `NSFileManager.trashItem`), delete, rename, mkdir. Each reports progress via `OperationProgressReporting` callback. Conflict detection returns a typed `ConflictDescriptor` rather than throwing.
4. `VolumeDiscovery`: enumerates mounted volumes via `FileManager.mountedVolumeURLs` plus `DADiskArbitration` for ejectability. Publishes an async stream of mount/unmount events.
5. `FSEventsWatcher`: wraps `FSEventStreamCreate` exposing async stream of `FilePath` change events. Honors recursive watch and coalesce window.
6. `SecurityScopedBookmarks`: encode/decode security-scoped bookmarks for sandboxed deployment; persist via `Data`. Provide `withAccess(to:_:)` async helper.
7. Tests use a unique `URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)` per test and tear down in `tearDown`. Cover symlink edge cases, permission-denied propagation, conflict descriptors, hidden-file filter.

Deliverables
- All source files above + comprehensive tests.
- `docs/roadmap/stevedore-mvp/session-03-handoff.md` documenting the provider's concurrency boundaries (actor reentrancy, cancellation), supported operations, and known macOS quirks.

Quality gates
- `swift build --target FileSystemLocal`
- `swift test --filter LocalTests`
- `swiftformat --lint Sources/FileSystem/Local Tests/FileSystemTests/LocalTests`
- `swiftlint --strict --path Sources/FileSystem/Local`

Exit criteria
- `LocalFileSystemProvider` passes a conformance test suite hosted in `Tests/FileSystemTests/LocalTests/Conformance.swift` (drive the same scenarios any provider must satisfy).
- No data races under `-Xswiftc -strict-concurrency=complete`.
- FSEvents watcher cancels cleanly on task cancellation; verified by a leak-detection test.
```
