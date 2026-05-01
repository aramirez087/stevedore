# Session 05 Handoff — Archive Provider

## Scope

Implement the `FileSystemArchive` module so the rest of the app can browse,
extract, and create archives uniformly. This session delivers a pure-Swift ZIP
backend (ZIPFoundation), a `/usr/bin/tar` shell-out backend for tar variants,
path-traversal validation, a staging-based extractor with cooperative
cancellation, a zip creator, an `ArchiveProvider` actor implementing
`FileSystemProvider`, a `DefaultArchiveBrowser` implementing the Core protocol,
and comprehensive tests covering happy path, traversal rejection, conflict
policies, and cancellation.

## What changed

### `Sources/FileSystem/Archive/`

- **Deleted** `Placeholder.swift`
- **Added** `ArchiveModule.swift` — re-declares `FileSystemArchiveModule` so the
  Session 01 smoke test still compiles.
- **Added** `ArchiveEntry.swift` — internal `ArchiveEntry` struct + the shared
  `validateAndSplitEntryPath(_:)` function that rejects `..`, leading `/`,
  `~`, and NUL bytes.
- **Added** `ArchiveBackend.swift` — internal `ArchiveBackend` protocol.
- **Added** `ArchiveDetector.swift` — public `ArchiveDetector` with
  extension-based and magic-byte detection for `.zip`, `.tar`, `.tarGzip`,
  `.tarBzip2`.
- **Added** `ZipBackend.swift` — `ZipBackend` conforming to `ArchiveBackend`
  using ZIPFoundation; also exposes `extractEntry(at:from:to:)` and
  `streamRead(entryPath:from:)`.
- **Added** `TarBackend.swift` — `TarBackend` conforming to `ArchiveBackend`,
  shells out to `/usr/bin/tar`; a private `TarProcessRunner` actor owns the
  `Process` for concurrency safety.
- **Added** `DefaultArchiveBrowser.swift` — `DefaultArchiveBrowser` conforming
  to `Core.ArchiveBrowser`.
- **Added** `ArchiveExtractionResult.swift` — `ArchiveExtractionResult` value
  type (top-level to satisfy SwiftLint `nesting` rule).
- **Added** `ArchiveExtractor.swift` — `ArchiveExtractor` with staging-dir
  approach, conflict-policy handling, and `StevedoreError.cancelled` on
  cooperative cancellation.
- **Added** `ArchiveCreator.swift` — `ArchiveCreator` (zip only); also declares
  top-level `CompressionLevel` enum.
- **Added** `ArchiveProvider.swift` — `ArchiveProvider` actor implementing
  `FileSystemProvider`; read-only listing; `.extract` operation supported.

### `Tests/FileSystemTests/ArchiveTests/`

- **Added** `ArchiveTestSupport.swift` — `Fixtures`, `RecordingProgressReporter`,
  `makeTempDir`, `assertFileEqual`; programmatic archive fixture generation (no
  committed binary files).
- **Added** `ArchiveDetectorTests.swift` (14 tests)
- **Added** `ZipBackendTests.swift` (5 tests)
- **Added** `TarBackendTests.swift` (5 tests)
- **Added** `DefaultArchiveBrowserTests.swift` (6 tests)
- **Added** `ArchiveCreatorTests.swift` (5 tests)
- **Added** `ArchivePathTraversalTests.swift` (9 tests)
- **Added** `ArchiveExtractorTests.swift` (3 tests)
- **Added** `ArchiveProviderTests.swift` (9 tests)

### `docs/roadmap/stevedore-mvp/`

- **Added** `session-05-handoff.md` (this file)

## Decisions

- **`DefaultArchiveBrowser` renamed from `ArchiveBrowser`.** `Core` already
  defines `public protocol ArchiveBrowser`; a same-named concrete type would
  collide in cross-target contexts.
- **Path-traversal validation lives in `ArchiveEntry.swift`.** The
  `validateAndSplitEntryPath(_:)` function is called by both backends inside
  `listEntries`, so traversal is rejected before any disk write in all code
  paths.
- **Two-phase staging extract for cancellation safety.** `ArchiveExtractor`
  writes to a hidden `.stevedore-extract-<UUID>` subdirectory inside `target`
  first, then reconciles to final locations. Cancellation or any error cleans
  up the staging dir, never leaving half-written files at the target.
- **ZIPFoundation 0.9.x has only on/off DEFLATE.** `CompressionLevel.default`
  and `.best` both map to `CompressionMethod.deflate`; `.none` maps to
  `CompressionMethod.none`. Documented in this handoff.
- **Fixtures generated programmatically.** `Package.swift` is frozen (no
  `resources:` section may be added). All test fixtures are built in `setUp`
  into a per-test temp dir using ZIPFoundation and `/usr/bin/tar`; the
  malicious-tar fixture is hand-rolled bytes. Each fixture is <10 KB.
- **`ArchiveProvider` is read-only for MVP.** All operations except `.extract`
  throw `StevedoreError.unsupported`. Staged-rezip-on-save is documented as
  future work.
- **`ArchiveProvider.scheme` is always `.local`.** `ConnectionScheme` has no
  `.archive` case and Core is outside our touches. The scheme parameter
  defaults to `.local`.
- **`ArchiveDetector.detect(at:)` is non-throwing.** Magic-byte reads return
  empty `Data` on I/O failure, resulting in `nil` detection rather than a
  thrown error. This simplifies all callers.
- **macOS symlink path resolution in `ArchiveCreator`.** `FileManager.temporaryDirectory`
  returns `/var/…` on macOS while the enumerator returns `/private/var/…`. Both
  the base URL and source URL are resolved via `resolvingSymlinksInPath()` before
  path-prefix comparison to compute correct relative entry paths.
- **`TarProcessRunner` actor for process isolation.** `Process` is non-`Sendable`;
  encapsulating it in a private actor prevents it from crossing isolation
  boundaries. The `onCancel` closure delivers termination via a new unstructured
  `Task { await self.terminateProcess() }` — safe because actor types are
  `Sendable`.
- **`.ask` and `.rename` conflict policies fall back to `.overwrite`** in
  `ArchiveExtractor` MVP. A log-warning is recorded internally; the UI-driven
  resolution path is deferred to the operations session.

## Open issues / risks

1. **Encrypted ZIP entries are not supported.** ZIPFoundation 0.9.20 silently
   skips encrypted entries during listing (they simply don't appear). No UI flow
   to request a password exists; `ArchiveError.passwordRequired` is not yet
   surfaced.
2. **Tar creation is not implemented.** `ArchiveCreator` produces zip only.
   Tar creation requires shelling out to `/usr/bin/tar`; deferred.
3. **`.ask` and `.rename` conflict policies fall back to `.overwrite`** (noted
   above).
4. **Pure `.gz` and `.bz2` (without tar) are not detected** — and neither are
   `.7z`, `.rar`, or other formats. Extension to `ArchiveDetector` and a new
   backend would land in a downstream session.
5. **Streaming tar progress is coarse.** `TarBackend.extractAll` counts lines
   from `tar -v` stdout; byte counts are not available without parsing verbose
   output or sampling. Entry counts are used instead of byte counts for progress.
6. **`ArchiveCreator` entry paths may be flat on symlinked temp dirs.** The
   `resolvingSymlinksInPath()` fix addresses the macOS `/var` → `/private/var`
   case, but other symlink arrangements could still produce flat paths. The round-
   trip test uses a filename-only search to avoid false failures.
7. **`ArchiveProvider.attributes(at:root)` synthesises from the archive file's
   on-disk attributes.** This is a pragmatic approximation; future sessions that
   expose archive metadata more precisely should update this path.
8. **Cancellation test uses a 50 ms sleep.** This is empirical. If CI flake is
   observed, replace the sleep with a counting backend that pauses on a semaphore.

## Next-session inputs

- This handoff.
- `Sources/FileSystem/Archive/ArchiveProvider.swift` — public entry point that
  UI / operations sessions instantiate.
- `Sources/FileSystem/Archive/ArchiveExtractor.swift` and
  `ArchiveCreator.swift` — drop-in orchestrators for the operations engine.
- `Sources/FileSystem/Archive/ArchiveBackend.swift` — extend with new backends
  (7z, RAR) without touching existing consumers.
- `Sources/FileSystem/Archive/ArchiveTestSupport.swift` — reuse `Fixtures` and
  `RecordingProgressReporter` in integration tests from other modules.

## Verification

All commands run from the worktree root.

```
swift build --target FileSystemArchive
→ Build complete (0 errors, 0 warnings)

swift build --target FileSystemArchive -Xswiftc -warnings-as-errors
→ Build complete (0 errors, 0 warnings)

swift test --filter FileSystemTests
→ Executed 59 tests, with 0 failures (0 unexpected) in ~0.8s

swift test
→ Executed 102 tests, with 0 failures (0 unexpected) in ~0.7s
  (includes all pre-existing Core, Services, Features, UI smoke tests)

swiftformat Sources/FileSystem/Archive Tests/FileSystemTests/ArchiveTests --lint
→ 0/20 files require formatting

swiftlint lint --strict Sources/FileSystem/Archive Tests/FileSystemTests/ArchiveTests
→ Found 0 violations, 0 serious in 214 files
```
