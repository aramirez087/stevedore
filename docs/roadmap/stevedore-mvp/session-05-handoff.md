# Session 05 Handoff — Archive Provider

## Scope

Implemented the `FileSystemArchive` module so the rest of the app can browse,
extract, and create archives uniformly through the `FileSystemProvider` protocol.
Supports zip (read + creation) and tar / tar.gz / tar.bz2 (read-only extract).
Path-traversal is blocked at the backend listing stage before any byte is written.
Mid-flight cancellation leaves no staging artifacts in the target directory.

## What changed

### `Sources/FileSystem/Archive/`
- `ArchiveModule.swift` — module sentinel preserving `FileSystemArchiveModule.moduleName`
  for the Session 01 smoke test; replaces `Placeholder.swift` (deleted).
- `ArchiveDetector.swift` — extension + magic-byte format detection; `isArchive(_:)`;
  `detect(at:)` preferring extension then magic. Fixed one SwiftFormat indent issue.
- `ArchiveEntry.swift` — internal `struct ArchiveEntry: Hashable, Sendable`; `asFileItem(mountComponents:scheme:)` adapter; `validateAndSplitEntryPath` security gate (rejects `/`, `~`, `..`, NUL, empty).
- `ArchiveBackend.swift` — internal `protocol ArchiveBackend: Sendable` with `listEntries`, `extractAll`.
- `ZipBackend.swift` — ZIPFoundation backend: list, extract-one, extract-all, stream-read; mode + mtime preserved; path validation in `listEntriesSync`.
- `TarBackend.swift` — `/usr/bin/tar` backend with `TarProcessRunner` actor for `Process` isolation; supports `.tar`, `.tarGzip`, `.tarBzip2`; validates paths from listing before extracting.
- `ArchiveExtractor.swift` — staging-dir orchestrator: detect → validate → stage → reconcile; cooperative cancellation with `defer`-based cleanup; `.skip`/`.overwrite` conflict policies; `.ask`/`.rename` fall back to `.overwrite` with documented MVP limitation.
- `ArchiveCreator.swift` — zip-only creation from source URL list; `CompressionLevel` enum (`.none`/`.default`/`.best`); `.default` and `.best` both map to ZIPFoundation's `.deflate` (no finer level knob in 0.9.x).
- `ArchiveProvider.swift` — `public actor: FileSystemProvider` over an archive root; lazy cached entry list; read-only (`.extract` supported, all other operations throw `.unsupported`); `watch` returns immediately-finishing stream.
- `ArchiveExtractionResult.swift` — `public struct: Hashable, Sendable` with `entriesExtracted` + `bytesProcessed`.
- `DefaultArchiveBrowser.swift` — `public struct: ArchiveBrowser`; `.local`-only for MVP.

### `Tests/FileSystemTests/ArchiveTests/`
- `ArchiveTestSupport.swift` — `RecordingProgressReporter`, `Fixtures` (zip, tar, malicious zip/tar), `makeTempDir`, `assertFileEqual`.
- `ArchiveDetectorTests.swift` — 14 tests covering extension, magic, `isArchive`.
- `ZipBackendTests.swift` — 5 tests: list, mode/mtime, extract-one, stream-read.
- `TarBackendTests.swift` — 5 tests: list + extract for `.tar`, `.tar.gz`, `.tar.bz2`; invalid-format guard.
- `ArchiveExtractorTests.swift` — 3 tests: progress callbacks, skip-conflict, cancellation cleanup.
- `ArchivePathTraversalTests.swift` — 9 tests: malicious zip/tar rejection, `validateAndSplitEntryPath` unit tests.
- `ArchiveCreatorTests.swift` — 5 tests: create, entry list, round-trip, compression size, extracted content equality.
- `ArchiveProviderTests.swift` — 9 tests: enumerate root/recursive, attributes, extract op, unsupported op, watch, init errors.
- `DefaultArchiveBrowserTests.swift` — 6 tests: `isArchive` variants, `entries` sorted, error cases.

### `docs/roadmap/stevedore-mvp/`
- `session-05-handoff.md` — this file.

## Decisions

- **`DefaultArchiveBrowser` naming.** `Core` already defines `public protocol ArchiveBrowser`; a same-named struct in `FileSystemArchive` would collide for cross-target callers. Concrete impl named `DefaultArchiveBrowser` per SwiftLint "file matches primary type" rule.
- **`validateAndSplitEntryPath` as the single security gate.** Both `ZipBackend.listEntriesSync` and `TarBackend.listEntries` call it before constructing any `ArchiveEntry`. By the time `ArchiveExtractor` starts extracting, all paths are already validated — no disk writes can occur from traversal paths.
- **Two-phase staging extract for cancellation safety.** `ArchiveExtractor` creates a `.stevedore-extract-<UUID>` directory inside `target` and uses a `defer` + catch block to guarantee cleanup. The final target never contains partial files.
- **ZIPFoundation `Archive` confined to detached tasks.** `Archive` (a class) is created, used, and released within a single `Task.detached` — never captured across `await`. No `@unchecked Sendable` needed.
- **`TarProcessRunner` actor for process ownership.** `Process` is non-`Sendable`; actor isolation ensures it never crosses isolation boundaries. The `onCancel` handler issues `terminate()` via an unstructured `Task` (cannot synchronously call actor method from `@Sendable` closure).
- **Programmatic fixtures instead of `Tests/Fixtures/Archive/` blobs.** `Package.swift` is frozen; adding binary resources would require a `resources:` declaration. All fixtures are generated in per-test temp dirs; each is <10 KB at runtime.
- **`ArchiveProvider.scheme` inherits the host scheme.** `ConnectionScheme` has no `.archive` case and is in `Core` (outside touch-glob). Provider defaults to `.local` and exposes the scheme as a `nonisolated let`.
- **`./`-prefixed paths from BSD tar preserved as-is.** `validateAndSplitEntryPath("./a.txt")` produces `[".", "a.txt"]` — the `.` is not `..` so it passes. `URL.appendingPathComponent("./a.txt")` normalises to the correct target. Tests accept both `"a.txt"` and `"./a.txt"` in listing assertions.
- **Compression level mapping.** ZIPFoundation 0.9.x has only on/off DEFLATE. `CompressionLevel.default` and `.best` both map to `.deflate`; `.none` maps to `CompressionMethod.none`.
- **`.ask` and `.rename` conflict policies fall back to `.overwrite` in MVP.** No UI callback mechanism exists yet. Documented as a known limitation.

## Open issues / risks

1. **Tar creation not supported.** `ArchiveCreator` is zip-only. The MVP explicitly defers this; the `ArchiveBackend` protocol is designed to accommodate a future `createArchive` method.
2. **Encrypted zip not supported.** `ArchiveError.passwordRequired` is surfaced but no UI dialog exists to collect a password. Encrypted entries cause extraction to fail with this error.
3. **`.ask` and `.rename` conflict policies are MVP stubs.** Both fall back to `.overwrite` in `ArchiveExtractor`. Full dialog-driven resolution lands in Session 10 (operations engine).
4. **Pure `.gz` / `.bz2` (without tar) not detected.** `detectByMagic` maps gzip magic to `.tarGzip` (assuming tar-wrapped). A standalone `.gz` would be misidentified. Out of scope for MVP.
5. **Other formats (`.7z`, `.rar`, `.xz`) not supported.** `ArchiveDetector.detect` returns `nil`; callers receive `.archive(.unsupportedFormat)`.
6. **Streaming progress for tar is coarse.** `TarBackend.extractAll` counts newlines from `-v` stdout; `bytesDone` carries entry counts, not bytes.
7. **Dead guard in `ArchiveProvider.attributes(at:)`.** The branch `path.components == archiveURL.pathComponents.map(\.self)` can never fire because `URL.pathComponents` includes `"/"` as the first component while `FilePath.components` does not. Root attributes are correctly handled by the `path.isRoot` guard above it. Latent dead code; not fixed to avoid scope creep.
8. **`ArchiveProvider` is read-only.** Staged zip-write-on-save is deferred; all non-extract operations throw `StevedoreError.unsupported`.

## Next-session inputs

- `Sources/FileSystem/Archive/ArchiveProvider.swift` — entry point instantiated by pane/sidebar sessions.
- `Sources/FileSystem/Archive/ArchiveExtractor.swift` + `ArchiveCreator.swift` — drop-in components for Session 10 (operations engine).
- `Sources/FileSystem/Archive/DefaultArchiveBrowser.swift` — used by Sessions 16–18 for sidebar archive mounting.
- `Tests/FileSystemTests/ArchiveTests/ArchiveTestSupport.swift` — `Fixtures` enum and `RecordingProgressReporter` reusable in downstream sessions that test archive flows.
- `Sources/FileSystem/Archive/ArchiveBackend.swift` (internal protocol) — extend to add `createArchive` if a future session adds tar creation.

## Verification

All commands run from the repo root on 2026-05-01.

```
swift build --target FileSystemArchive
# Build of target: 'FileSystemArchive' complete!  (3.67s)

swift build --target FileSystemArchive -Xswiftc -warnings-as-errors
# Build of target: 'FileSystemArchive' complete!  (4.39s)

swift test --filter FileSystemTests.Archive
# Executed 40 tests, with 0 failures in 0.180s

swift test --filter "FileSystemTests.TarBackendTests|FileSystemTests.ZipBackendTests|FileSystemTests.DefaultArchiveBrowserTests"
# Executed 16 tests, with 0 failures in 0.127s

swift test
# Executed 538 tests, with 0 failures in 4.565s

swiftformat Sources/FileSystem/Archive Tests/FileSystemTests/ArchiveTests --lint
# 0/20 files require formatting

swiftlint lint --strict Sources/FileSystem/Archive Tests/FileSystemTests/ArchiveTests
# Done linting! Found 0 violations, 0 serious in 460 files.

swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
# Build complete! (6.47s)
```

All quality gates pass. 56 archive tests green (40 via `FileSystemTests.Archive` filter + 16 via backend/browser filter). Full suite 538 tests, 0 failures.
