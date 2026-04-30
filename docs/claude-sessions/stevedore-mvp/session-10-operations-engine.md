---
session: 10
title: "File Operations Engine"
depends_on: [01, 02, 03, 04, 05, 09]
touches:
  - Sources/Features/Operations/**
  - Tests/FeaturesTests/OperationsTests/**
parallel_safe: true
---

# Session 10: File Operations Engine

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 03, 04, 05, 09 artifacts. Read each session's handoff. Use the providers via the `FileSystemProvider` protocol — never reach into concrete impls.

Mission
Provide a queue-driven engine that executes batched file operations (copy, move, delete, rename, mkdir, archive, extract) across any combination of providers, with progress reporting, conflict resolution, cancellation, and pause/resume.

Repository anchors
- Sources/Features/Operations/OperationQueue.swift (actor)
- Sources/Features/Operations/OperationExecutor.swift
- Sources/Features/Operations/Operation.swift (typed: copy, move, delete, rename, mkdir, archive, extract, sync-step)
- Sources/Features/Operations/ConflictPolicy.swift (skip, replace, rename-with-suffix, ask)
- Sources/Features/Operations/TransferProgress.swift (per-op + aggregate)
- Sources/Features/Operations/Throughput.swift (sliding-window bytes/sec estimator)
- Sources/Features/Operations/CrossProviderCopy.swift (chunked stream copy local↔remote)
- Tests/FeaturesTests/OperationsTests/*.swift

Tasks
1. `OperationQueue` actor maintains a list of pending/active/completed operations. Concurrency cap configurable (default 2).
2. `Operation` describes the work declaratively. `OperationExecutor` interprets it against the relevant providers via dependency injection.
3. `ConflictPolicy` resolves collisions: skip, replace, rename-with-suffix `(N)`, or `.ask` which suspends until a continuation is provided. Suspension uses async continuation, never busy-waits.
4. `TransferProgress` reports per-operation bytes-done/total + aggregate queue progress; throttle UI updates to ~10 Hz.
5. `Throughput` computes a sliding-window MB/s estimate for ETA display.
6. `CrossProviderCopy` streams data when source ≠ destination provider — reads chunks (256KB default) from source, writes to destination, propagating cancellation.
7. Cancellation is cooperative — every chunk loop checks `Task.isCancelled` and unwinds cleanly. Pause/resume via async semaphore.
8. Tests: synthetic providers from `Sources/Core/Testing` drive copy/move/delete scenarios; conflict policy covers each branch; throughput math validated; cancellation leaves no half-written files (verified after each cancel test).

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-10-handoff.md` covering operation lifecycle states, conflict policy semantics, and the API the Transfers UI will subscribe to.

Quality gates
- `swift build --target FeaturesOperations`
- `swift test --filter OperationsTests`
- `swiftformat --lint Sources/Features/Operations Tests/FeaturesTests/OperationsTests`
- `swiftlint --strict --path Sources/Features/Operations`

Exit criteria
- Cross-provider copy passes a fixture where source is `InMemoryFileSystemProvider` and dest is `LocalFileSystemProvider` (or its in-memory shim).
- Pausing an in-flight operation halts byte progression within 100ms; resuming continues from the same offset.
- Cancellation tests verify zero leaked file handles via `lsof`-equivalent counts (or by ensuring partial files are removed).
```
