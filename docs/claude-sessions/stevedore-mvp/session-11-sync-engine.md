---
session: 11
title: "Folder Sync & Compare Engine"
depends_on: [01, 02, 03, 04, 09]
touches:
  - Sources/Features/Sync/**
  - Tests/FeaturesTests/SyncTests/**
parallel_safe: true
---

# Session 11: Folder Sync & Compare Engine

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 03, 04, 09 artifacts. Read each handoff. Use `FileSystemProvider` abstractly; do not depend on concrete providers.

Mission
Implement folder comparison and one-way / two-way synchronization between any two `FileSystemProvider` roots — the mechanism the Sync dialog will drive.

Repository anchors
- Sources/Features/Sync/FolderComparator.swift
- Sources/Features/Sync/Difference.swift (matched, modified, leftOnly, rightOnly)
- Sources/Features/Sync/SyncPlan.swift
- Sources/Features/Sync/SyncEngine.swift (executes a plan against providers)
- Sources/Features/Sync/SyncOptions.swift (mode: oneWayMirror | oneWayContribute | twoWay; ignore globs; size+mtime tolerance)
- Sources/Features/Sync/HashStrategy.swift (size+mtime fast path; optional sha256 deep compare)
- Tests/FeaturesTests/SyncTests/*.swift

Tasks
1. `FolderComparator` walks both sides concurrently (TaskGroup), reports `Difference` rows. Honors ignore globs via Core utilities.
2. Default comparison: size + mtime (within tolerance). Optional deep mode hashes contents with cancellable streaming sha256.
3. `SyncPlan` is a list of `Operation`s derived from differences + `SyncOptions`. Plan generation is pure — no I/O — so it is unit-testable.
4. `SyncEngine` hands the plan to the Operations engine (Session 10) when integrated; for this session, define the planner and provide a unit-testable executor that takes an `OperationExecutor`-shaped collaborator.
5. Conflict semantics for two-way sync: configurable — newer-wins, larger-wins, manual. Manual returns a continuation per conflict.
6. Progress reporting bridges to the Operations engine's `TransferProgress`; from this session, expose a sync-level progress aggregator (rows compared, rows pending, rows done).
7. Tests: comparator over fixture trees in `InMemoryFileSystemProvider`, ignore globs, hash mismatches, two-way conflict resolution paths.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-11-handoff.md` covering sync modes, conflict policies, and the Sync dialog's required API.

Quality gates
- `swift build --target FeaturesSync`
- `swift test --filter SyncTests`
- `swiftformat --lint Sources/Features/Sync Tests/FeaturesTests/SyncTests`
- `swiftlint --strict --path Sources/Features/Sync`

Exit criteria
- Plan generation is deterministic for a given input and produces no operations when sources are identical.
- Hash-based deep compare cancels mid-stream when the parent task is cancelled.
- Two-way sync correctly identifies "both modified" conflicts and surfaces them via the manual-resolution continuation.
```
