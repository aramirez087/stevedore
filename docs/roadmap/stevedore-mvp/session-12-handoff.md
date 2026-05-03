# Session 12 Handoff — Multi-Rename Engine

## Scope

Implement the batch rename engine for Stevedore's `FeaturesRename` module. The engine
takes a list of `FileItem`s and a `RenameRecipe` (an ordered list of `RenameStep`s),
produces a previewed list of `RenameOutcome`s with conflict detection, and executes them
via a `FileSystemProvider` with journal-backed rollback on partial failure.

## What changed

### `Sources/Features/Rename/` (7 files)

- **`FeaturesRenameModule.swift`** — Replaces `Placeholder.swift`; preserves the
  `FeaturesRenameModule.moduleName` sentinel consumed by the pre-existing smoke test.

- **`RenameStep.swift`** — `public enum RenameStep` with 7 cases: `find`, `regex`,
  `` `case` ``, `sequence`, `trim`, `insert`, `` `extension` ``. Five supporting top-level
  enums: `CaseTransform`, `TrimPosition`, `SequencePosition`, `ExtensionTransform`,
  `InsertPosition`. `InsertPosition` has manual `Codable` with a `type` discriminator key
  (consistent with `OperationKind`). All enums are `Sendable`, `Codable`, `Hashable`.
  Public `func apply(to:ext:index:)` applies a step in-place on decomposed stem/ext strings.
  Private helper functions `renameSplitStemExt` and `renameAssembled` are module-internal
  (no access modifier) so `RenamePlanner` can reuse them.

- **`RenameRecipe.swift`** — `public struct RenameRecipe: Sendable, Codable, Hashable` with
  ordered `steps: [RenameStep]` and a static `identity` constant.

- **`RenameOutcome.swift`** — `public enum RenameStatus` (`.ok`, `.collision`,
  `.invalid(reason: String)`) and `public struct RenameOutcome` bundling the original
  `FileItem`, computed `targetName`, and `status`.

- **`CollisionResolver.swift`** — `public enum CollisionResolver` with nested
  `public enum Strategy` (`.markInvalid`, `.autoSuffix`) and a pure static
  `resolve(outcomes:existingSiblings:strategy:)` function. Auto-suffix inserts before the
  extension: `"foo.txt"` → `"foo 2.txt"`, matching Finder behavior. First item claiming
  a name wins; subsequent items are suffixed or marked `.collision`.

- **`RenamePlanner.swift`** — `public enum RenamePlanner` with a pure static
  `plan(items:recipe:existingSiblings:collisionStrategy:)` function. Validates all
  `.regex` patterns via `NSRegularExpression` before processing any items (plan-time
  rejection); malformed patterns short-circuit and mark all items `.invalid`. Applies steps
  deterministically by (item, index) then delegates collision resolution to
  `CollisionResolver`.

- **`RenameExecutor.swift`** — `public actor RenameExecutor` with `JournalEntry` struct,
  `execute(outcomes:in:using:)`, and `reset()`. Forward renames are journaled per step; on
  any failure, `rollback(using:)` reverses completed renames in reverse journal order using
  `try?` (best-effort). Rollback failures are logged via `os.Logger` without re-throwing.

### `Tests/FeaturesTests/RenameTests/` (5 new files)

- **`RenameTestSupport.swift`** — `testSplitStemExt`, `testAssembled`, `applyStep`
  free functions mirroring private rename helpers; `makeItem` helper; `RecordingRenameProvider`
  actor implementing `FileSystemProvider` with a call-indexed failure mechanism
  (`failAtRenameIndices: Set<Int>`).

- **`RenameStepTests.swift`** — 25 tests covering all 7 step types including Unicode
  case folding, very long stems, hidden files (`.gitignore` has no extension), trim
  leading/trailing/both, insert at index beyond end, and sequence padding overflow.

- **`RenamePlannerTests.swift`** — 15 tests covering empty input, identity recipe,
  multi-step ordering, determinism (identical calls produce identical arrays), regex
  validation (valid and malformed), backreference resolution, within-batch collision
  detection, existing-sibling conflict, long names, and Unicode normalization.

- **`CollisionResolverTests.swift`** — 10 tests covering no-collision passthrough,
  within-batch mark-invalid and auto-suffix, sibling mark-invalid and auto-suffix,
  suffix chain (skip already-taken suffixes), no-extension auto-suffix, pass-through of
  non-ok statuses, first-claimer ordering, and large suffix counter (N=5).

- **`RenameExecutorTests.swift`** — 10 tests including the exit-criterion rollback test
  (fail on rename 5 of 10, assert first 4 reversed and items 5–10 untouched), a
  best-effort rollback test (rollback call 7 of 9 fails, other 3 rollbacks succeed), skip
  of `.collision`/`.invalid` outcomes, journal population, reset, directory appending,
  error propagation, and empty-outcomes no-op.

### `docs/roadmap/stevedore-mvp/session-12-handoff.md`

This document.

### Deleted

- `Sources/Features/Rename/Placeholder.swift` — replaced by `FeaturesRenameModule.swift`.

## Decisions

- **`find` and `regex` steps operate on the assembled name** (stem + "." + ext); all other
  steps operate on `stem` or `ext` separately. After `find`/`regex` transforms, the name
  is re-split by `renameSplitStemExt`.

- **Hidden files have no extension.** `renameSplitStemExt(".gitignore")` returns
  `(stem: ".gitignore", ext: nil)` because the leading dot is at `startIndex`. The
  `` `extension` `` step is a no-op on hidden files.

- **Regex rejected at plan time, not execution time.** `RenamePlanner.validateRecipe`
  compiles all regex patterns before iterating items. A bad pattern short-circuits and
  marks all items `.invalid`. This satisfies the exit criterion without exposing errors
  at the `FileSystemProvider` layer.

- **`sequence` step uses no separator.** `sequence(start:1, padding:3, position:.prefix)`
  on `"photo.jpg"` → `"001photo.jpg"`. A separator can be injected via an `insert` step.

- **`InsertPosition.beforeExtension` is semantically identical to `.suffix` on the stem.**
  Since `apply` receives an already-decomposed stem (no extension present), appending text
  to the stem is equivalent to inserting before the extension in the final assembled name.

- **Auto-suffix format matches macOS Finder:** `"foo.txt"` → `"foo 2.txt"` (space before
  counter, before the extension). Files without extensions: `"readme"` → `"readme 2"`.

- **`RenameExecutor.rollback` uses `os.Logger`** from the `os` system framework rather than
  adding `ServicesLogging` as a dependency (Package.swift is frozen).

- **`RecordingRenameProvider.renameCallCount`** counts ALL rename calls (forward + rollback)
  regardless of success/failure. `failAtRenameIndices` is a `Set<Int>` of 1-indexed call
  numbers. This allows tests to inject failures at specific rollback positions without
  relying on success-count arithmetic.

- **`renameSplitStemExt` / `renameAssembled` are module-internal**, not private to the
  `RenameStep.swift` file. This avoids duplicating the stem/ext logic in `RenamePlanner`
  and the test support file.

## Open issues / risks

1. **EXIF metadata step not implemented.** The session context mentioned EXIF but the
   task list does not include it. EXIF requires `ImageIO` reads during planning, breaking
   the pure-function invariant and requiring a new framework dependency. Deferred to the
   Rename dialog session (22) if needed.

2. **`GlobMatcher` does not support bracket sets (`[abc]`) or brace expansion** — noted
   in Session 02. The rename engine does not use `GlobMatcher` directly; this is only
   relevant if a future filter-by-name step is added.

3. **`sequence` step using `String(format:)` with very large padding values** could
   produce unexpectedly long strings. No truncation is applied (documented in tests as
   correct behavior), but callers should validate user input before constructing recipes.

4. **Rollback is best-effort.** If a rollback rename fails, the file remains at the
   renamed path. The Rename dialog (Session 22) should surface the executor's journal
   after a failed batch so the user knows which files remain renamed.

## Session 22 API Contract (RenameDialog UI)

**Preview flow** (called on every keystroke):
```swift
let outcomes = RenamePlanner.plan(
    items: selectedItems,
    recipe: currentRecipe,
    existingSiblings: siblingsInDirectory,
    collisionStrategy: .markInvalid
)
// Bind outcomes to the preview table
```

**Commit flow** (on user confirmation):
```swift
let executor = RenameExecutor()
try await executor.execute(
    outcomes: outcomes,   // executor skips .collision and .invalid internally
    in: currentDirectory,
    using: activeProvider
)
```

The executor skips `.collision` and `.invalid` outcomes automatically. Pre-filtering to
`.ok` before passing is valid and slightly more efficient but not required.

## Next-session inputs

Sessions depending on Session 12 (primarily Session 22 — RenameDialog UI) should read:

- `Sources/Features/Rename/RenameStep.swift` — step enum, supporting enums, `apply` API.
- `Sources/Features/Rename/RenameRecipe.swift` — `RenameRecipe.identity` for "no steps" case.
- `Sources/Features/Rename/RenameOutcome.swift` — `RenameStatus` for driving preview table
  row colors (`.ok` → normal, `.collision` → warning, `.invalid` → error).
- `Sources/Features/Rename/RenamePlanner.swift` — call `plan(items:recipe:existingSiblings:collisionStrategy:)`.
- `Sources/Features/Rename/RenameExecutor.swift` — actor; call `execute(outcomes:in:using:)`
  and `reset()`.
- `Tests/FeaturesTests/RenameTests/RenameTestSupport.swift` — `RecordingRenameProvider` for
  dialog integration tests.
- Non-obvious: `InsertPosition.beforeExtension` and `.suffix` are behaviorally identical
  on decomposed stems. Display them as distinct UI options, but test both.

## Verification

All commands run from the repo root.

```
swift build --target FeaturesRename
→ Build of target: 'FeaturesRename' complete! (0 warnings)

swift test --filter FeaturesTests
→ Executed 161 tests, with 0 failures (0 unexpected)

swiftformat Sources/Features/Rename Tests/FeaturesTests/RenameTests --lint
→ 0/12 files require formatting

swiftlint lint --strict Sources/Features/Rename
→ Done linting! Found 0 violations, 0 serious in 268 files

swift build -Xswiftc -warnings-as-errors
→ Build complete! (0 warnings, strict concurrency)

swift test
→ Executed 693 tests, with 0 failures (0 unexpected)
```
