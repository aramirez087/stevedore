---
session: 05
title: "Archive Provider"
depends_on: [01]
touches:
  - Sources/FileSystem/Archive/**
  - Tests/FileSystemTests/ArchiveTests/**
parallel_safe: true
---

# Session 05: Archive Provider

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01 artifacts. Read `docs/roadmap/stevedore-mvp/session-01-handoff.md`. ZIPFoundation is already pinned in Package.swift on the FileSystemArchive target.

Mission
Let the user browse, extract, and create archives as if they were folders — zip, tar, tar.gz, tar.bz2 — exposing them through the same `FileSystemProvider` protocol so the UI never special-cases them.

Repository anchors
- Sources/FileSystem/Archive/ArchiveProvider.swift (FileSystemProvider over an archive root)
- Sources/FileSystem/Archive/ArchiveBrowser.swift (entries listing, kind detection)
- Sources/FileSystem/Archive/ZipBackend.swift (ZIPFoundation)
- Sources/FileSystem/Archive/TarBackend.swift (uses Foundation `Process` to shell out to /usr/bin/tar)
- Sources/FileSystem/Archive/ArchiveExtractor.swift (extraction with progress + conflict resolution)
- Sources/FileSystem/Archive/ArchiveCreator.swift (creation from a list of source URLs)
- Tests/FileSystemTests/ArchiveTests/*.swift (uses small binary fixtures under Tests/Fixtures/Archive/)

Tasks
1. Detect archive kind from extension and magic bytes; expose `isArchive(_:)`. Handle `.zip`, `.tar`, `.tar.gz`/`.tgz`, `.tar.bz2`/`.tbz2`.
2. `ArchiveProvider` mounts an archive at a virtual root. Listing is read-only for the MVP; writing is staged in a temp dir and rezipped on save (zip only).
3. `ZipBackend`: pure Swift via ZIPFoundation. Expose listing, extract-one, extract-all, stream-read entry. Preserve file modes and modification dates.
4. `TarBackend`: shell out to `/usr/bin/tar` with explicit args; capture progress via byte counts on stdout. Validate paths — reject `..` and absolute path entries to prevent path-traversal.
5. `ArchiveExtractor`: orchestrates a backend + a target directory + an `OperationProgressReporting` callback; emits per-entry progress and supports cancellation.
6. `ArchiveCreator`: builds zip archives from a list of source URLs preserving relative paths. Compression level configurable.
7. Tests: round-trip create→extract for zip; extract-only for tar fixtures; security tests for path traversal; cancellation test (cancels mid-extract and asserts partial cleanup).

Deliverables
- All source files above with tests covering happy path, traversal rejection, and cancellation.
- Small binary fixtures under `Tests/Fixtures/Archive/` (each <50KB).
- `docs/roadmap/stevedore-mvp/session-05-handoff.md` covering supported archive types, known limitations (e.g., zip-only writes), and security considerations.

Quality gates
- `swift build --target FileSystemArchive`
- `swift test --filter ArchiveTests`
- `swiftformat --lint Sources/FileSystem/Archive Tests/FileSystemTests/ArchiveTests`
- `swiftlint --strict --path Sources/FileSystem/Archive`

Exit criteria
- `ArchiveProvider` passes the shared conformance suite for read-only listing.
- Path-traversal attempts in malicious tarballs are rejected by `TarBackend` — verified by a dedicated test.
- Cancellation mid-extract leaves no half-written files in the target dir.
```
