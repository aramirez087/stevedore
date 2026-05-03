# Session 10 Handoff — Operations Engine

## Scope

Implement the `FeaturesOperations` module: a queue-driven file operations engine supporting same-provider and cross-provider transfers, with bounded concurrency, pause/resume, cooperative cancellation, conflict resolution, and 10 Hz progress reporting.

## What changed

### `Sources/Features/Operations/`
- **Deleted**: `Placeholder.swift` — replaced by the module files below.
- **`FeaturesOperationsModule.swift`** — Module sentinel `public enum FeaturesOperationsModule` with `moduleName = "FeaturesOperations"`. Keeps `FeaturesOperationsSmokeTests` passing.
- **`CrossProviderCopy.swift`** — Three declarations:
  - `DataReadableProvider: FileSystemProvider` — adds `read(at:chunkSize:) -> AsyncThrowingStream<Data, any Error>`.
  - `DataWritableProvider: FileSystemProvider` — adds `writeChunk(_:to:isFirst:isLast:) async throws` and `deletePartial(at:) async throws`.
  - `PauseResumeGate` actor — `checkPoint()` suspends via `[CheckedContinuation<Void, Never>]` when paused; avoids `DispatchSemaphore` (banned in async contexts).
  - `CrossProviderCopy` struct — one-chunk lookahead loop; calls `deletePartial` on any error (including `CancellationError`); cooperative cancellation via `Task.checkCancellation()` before each write.
- **`Throughput.swift`** — `ThroughputEstimator` struct: sliding-window samples `[(ContinuousClock.Instant, Int64)]`; `bytesPerSecond: Int64?` (nil < 2 samples); `estimatedSecondsRemaining(bytesLeft:) -> Double?`.
- **`TransferProgress.swift`** — `TransferProgress` per-op struct with `fraction: Double?` clamped to 1.0; `QueueProgress` aggregate; `TransferProgressTracker` actor throttling at 100 ms (always emits on `complete`).
- **`Operation.swift`** — `OperationState` top-level enum (`.pending/.active/.paused/.completed/.failed/.cancelled`); `Operation: Sendable, Identifiable` value type.
- **`ConflictPolicy.swift`** — `ConflictResolution` enum (`.skip/.replace/.renameWithSuffix`); `ConflictResolver` actor mapping `Core.ConflictPolicy` → `ConflictResolution`; `.ask` suspends via `[FilePath: CheckedContinuation<ConflictResolution, Never>]`; `static func uniquePath(for:existingPaths:)` appends " (N)" suffix.
- **`OperationExecutor.swift`** — Dispatches same-scheme ops to `sourceProvider.execute(_:progress:)`; cross-scheme ops to `CrossProviderCopy` (requires both providers to conform to `DataReadableProvider`/`DataWritableProvider`); infers `primaryScheme` from `sources.first?.scheme ?? destination?.scheme` so destination-only ops like `.mkdir` work without source paths.
- **`OperationQueue.swift`** — `FileOperationQueue` actor: `operations: [Operation]` single source of truth; `activeTasks`, `gates` dictionaries; `drain()` starts up to `maxConcurrency - active.count` tasks; `operationStream() -> AsyncStream<[Operation]>` subscription pattern (nonisolated factory, unstructured `Task` for continuation registration).

### `Tests/FeaturesTests/OperationsTests/`
- **`OperationsTestSupport.swift`** — `TestDataProvider` actor (`DataReadableProvider & DataWritableProvider`) with `[FilePath: Data]` backing, `simulatedChunkSize` control, `seed`/`data`/`deletePartialCalls`; `RecordingProgressReporter` actor; `FilePath.local`/`FilePath.remote` test helpers.
- **`ConflictResolverTests.swift`** — 9 tests including `.ask` suspension with `Task { () -> ConflictResolution in ... }` pattern (explicit return type prevents `Sendable` capture of `self`).
- **`CrossProviderCopyTests.swift`** — 8 tests including `SlowWriteProvider` (private actor, 5 ms/write) for pause/resume and cancellation tests; `testCancelCleansUpPartialFile` verifies `deletePartial` is called; `testPauseHaltsByteProgressionWithin100ms` verifies ≤1 chunk advances during pause window.
- **`OperationExecutorTests.swift`** — 7 tests covering same-provider ops, cross-provider copy with data integrity check, conflict skip, missing provider error, and no-paths error.
- **`FileOperationQueueTests.swift`** — 7 tests using deadline-based polling pattern (`awaitState`) with 20 ms sleep intervals; `FeaturesOperations.Operation` qualified name avoids ambiguity with `Foundation.NSOperation`.
- **`OperationTests.swift`** — 5 tests for `Operation` value type and `OperationState` transitions.
- **`ThroughputTests.swift`** — 6 tests for `ThroughputEstimator` including nil-before-two-samples, windowing, and ETA calculation.
- **`TransferProgressTests.swift`** — 7 tests for `TransferProgress` fraction clamping, `QueueProgress` aggregation, and `TransferProgressTracker` throttling.

## Test results

All 55 `FeaturesTests` pass. Full suite (587 tests) passes with 0 failures.

## Quality gates

| Gate | Result |
|------|--------|
| `swift build --target FeaturesOperations -Xswiftc -warnings-as-errors` | ✅ 0 warnings |
| `swift test` (587 tests) | ✅ 0 failures |
| `swiftformat … --lint` | ✅ 0 files require formatting |
| `swiftlint lint --strict Sources/Features/Operations` | ✅ 0 violations |
| `swiftlint lint --strict Tests/FeaturesTests/OperationsTests` | ✅ 0 violations |

## Decisions

- **`FileOperationQueue` not `OperationQueue`.** `Foundation.OperationQueue` is a concrete class in the same namespace; naming the actor `FileOperationQueue` avoids conflict without requiring a `Foundation` import suppression.
- **`OperationState` top-level, not nested.** SwiftLint `nesting` rule prohibits enums nested inside actors. Declared at module level with `// MARK: - OperationState` marker.
- **`primaryScheme = sourceScheme ?? destScheme`.** Enables destination-only operations (`.mkdir`, `.delete` with only a destination) to infer the provider from the destination path rather than requiring a source. This was discovered as a necessary fix during testing.
- **`async` on `cancel`/`pause`/`resume`/`cancelAll`.** `PauseResumeGate` actor methods are isolated, so calling them from `FileOperationQueue` methods requires `await`. All four queue methods are `async` as a result.
- **Deadline-based polling in `FileOperationQueueTests`.** Using `AsyncStream.next()` in a fixed loop hung indefinitely when no new events arrived. Replaced with `awaitState(queue:timeout:predicate:)` that polls `snapshot()` (fresh stream per call) with 20 ms sleep intervals and a 5 s deadline.
- **`swiftlint:disable function_parameter_count` regions.** `CrossProviderCopy.copy(from:on:to:on:gate:progress:)` and `OperationExecutor.copyFile(descriptor:source:destination:readable:writable:gate:)` each need 6 parameters; the symmetric `from`/`to` pairs are idiomatic Swift API design. Region-based disables are used to satisfy the lint rule while preserving the public API shape.
- **`guard let first/last` instead of `first!/last!`.** Force unwraps in `ThroughputEstimator` were technically safe (guarded by `count >= 2`) but violated `force_unwrapping` SwiftLint rule. Replaced with `guard let` bindings.

## Exit criteria met

- [x] `FileOperationQueue` actor with bounded concurrency and drain
- [x] `OperationExecutor` dispatching same-provider and cross-provider ops
- [x] `ConflictResolver` actor with `.ask` suspension pattern
- [x] `TransferProgressTracker` actor with 10 Hz throttle
- [x] `ThroughputEstimator` sliding-window estimator
- [x] `CrossProviderCopy` with pause/resume via `PauseResumeGate` and cancel cleanup
- [x] `DataReadableProvider` and `DataWritableProvider` protocols
- [x] Full test suite: ConflictResolver (9), CrossProviderCopy (8), OperationExecutor (7), FileOperationQueue (7), Operation (5), Throughput (6), TransferProgress (7) = 49 new tests + 6 smoke tests = 55 total in `FeaturesTests`
