# Session 03 Handoff — Local Filesystem Provider

## Scope

Implement `LocalFileSystemProvider`, the production-ready `FileSystemProvider` conformance for
the local macOS filesystem. Covers directory enumeration, attribute reading, all supported
file operations (copy / move / delete / rename / mkdir / symlink / trash), change watching via
FSEvents, volume discovery via DiskArbitration, and security-scoped bookmark helpers. All code
is under Swift 6 strict concurrency (`-strict-concurrency=complete`, `-warnings-as-errors`).

---

## What changed

### `Sources/FileSystem/Local/`

- **`FileSystemLocalModule.swift`** — replaces `Placeholder.swift`; preserves the
  `FileSystemLocalModule.moduleName` sentinel consumed by the pre-existing smoke test.
- **`LocalFileSystemProvider.swift`** — `public actor` conforming to `FileSystemProvider`.
  Routes `enumerate`/`watch` through `nonisolated` factories; funnels blocking I/O to
  `Task.detached`. Exposes `detectConflicts(for:)` as a preflight API.
- **`LocalDirectoryEnumerator.swift`** — bridges `FileManager.enumerator` into
  `AsyncThrowingStream<FileItem, any Error>`. Checks directory readability before creating
  the enumerator so permission-denied errors surface as `StevedoreError.fileSystem(.permissionDenied)`.
- **`URLResourceMapper.swift`** — translates `URLResourceValues` → `FileKind` / `FileAttributes`.
  Extracts POSIX permissions via `CFFileSecurityGetMode`. Reads symlink targets via
  `FileManager.destinationOfSymbolicLink`.
- **`LocalFileOperations.swift`** — stateless `struct` implementing copy/move/delete/rename/mkdir/
  symlink/trash. Each method creates a fresh `FileManager()` inside `Task.detached` (Apple
  threading guideline). Drives `OperationProgressReporting` with `.preparing` and `.completed`
  phases.
- **`ConflictDescriptor.swift`** — `public struct` returned by `detectConflicts(for:)`.
  Encodes source, destination, `Reason` (`.destinationExists`, `.destinationIsDirectory`,
  `.destinationReadOnly`, `.crossDeviceMove`), and `OperationKind`.
- **`FSEventsWatcher.swift`** — `public actor` wrapping `FSEventStreamCreate`. Each
  `events(for:recursive:)` call creates a fresh stream; `continuation.onTermination` stops,
  invalidates, and releases the stream. `FSEventStreamRef` is wrapped in a heap-allocated
  `StreamRef` class to satisfy `@Sendable` closure capture rules.
- **`VolumeDiscovery.swift`** — `public actor` wrapping a `DASession`. Disk info is extracted
  on the DA queue before any actor hop, passing only `Sendable` values (strings, bools) across
  the isolation boundary.
- **`Sandbox/SecurityScopedBookmarks.swift`** — encode/decode bookmarks with security-scope
  fallback for non-sandboxed unit tests. `withAccess(to:_:)` balances start/stop via `defer`.

### `Tests/FileSystemTests/LocalTests/`

- `Support/TempDirectoryFixture.swift` — per-test `UUID`-keyed scratch dir with permission
  restoration in `tearDown`.
- `LocalDirectoryEnumeratorTests.swift` — 7 tests (empty dir, list, hidden filter,
  recursive, non-recursive, mid-stream cancellation, notFound error).
- `SymlinkEdgeCasesTests.swift` — 3 tests (broken symlink enumerated, attributes readable,
  symlink-traversal toggle).
- `LocalFileOperationsTests.swift` — 12 tests (mkdir, copy ×3 policies, move, delete ×2,
  rename, symlink, trash, progress callback).
- `ConflictDescriptorTests.swift` — 4 tests (clear dest, existing file, existing dir, mkdir).
- `PermissionDeniedTests.swift` — 2 tests (enumerate permission denied, attributes on locked dir).
- `FSEventsWatcherTests.swift` — 4 tests (event emission, stream terminates on break,
  weak-reference dealloc, provider integration).
- `VolumeDiscoveryTests.swift` — 3 tests (boot volume present, names non-empty, stream smoke).
- `SecurityScopedBookmarksTests.swift` — 3 tests (round-trip, withAccess, error propagation).
- `LocalFileSystemProviderTests.swift` — 5 tests (scheme, attrs round-trip, missing path,
  non-local path rejection, archive unsupported).
- `Conformance.swift` — 14-test `ProviderConformanceTests` base class + `LocalProviderConformanceTests`
  subclass covering the full exit-criterion scenario list.

### `docs/roadmap/stevedore-mvp/session-03-handoff.md`
- This document.

---

## Decisions

- **Actor + `nonisolated` streams.** `enumerate` and `watch` are `nonisolated` so callers
  receive stream handles synchronously without awaiting actor isolation. This mirrors the
  `InMemoryFileSystemProvider` pattern from Session 01.
- **`Task.detached` for all blocking I/O.** `FileManager` calls are synchronous and can block
  for seconds. Funnelling them through `Task.detached(priority: .utility)` keeps the actor
  executor free and lets Swift's structured-concurrency cancellation propagate naturally.
- **No stored `FileManager` in `LocalFileOperations`.** `FileManager` is not `Sendable`.
  Each static method creates a fresh instance; this matches Apple's threading guidance and
  avoids `@unchecked Sendable`.
- **Explicit readability preflight in `LocalDirectoryEnumerator`.** `FileManager.enumerator`
  silently returns an empty sequence on an inaccessible root. We call `isReadableFile` first
  so `permissionDenied` surfaces consistently.
- **`unsafeBitCast` for FSEvents `eventPaths`.** When `kFSEventStreamCreateFlagUseCFTypes` is
  set, `eventPaths` is a `CFArray` of `CFString`; the parameter is typed as
  `UnsafeMutableRawPointer` so a `CFArray` bridge cast is required.
- **`StreamRef` heap box for `FSEventStreamRef`.** `FSEventStreamRef` is `OpaquePointer`,
  which is not `Sendable`. Boxing it in a `final class` marked `@unchecked Sendable` lets
  `continuation.onTermination` (a `@Sendable` closure) capture it cleanly.
- **DA callback info extracted before actor hop.** `DADisk` is a C type and not `Sendable`.
  All needed fields are copied to Swift value types on the DA dispatch queue before `Task {
  await … }` hops to the actor.
- **`detectConflicts(for:)` as a separate preflight method.** The `Core.FileSystemProvider`
  protocol surface is fixed; `OperationResult` cannot carry conflict metadata. The preflight
  API is `public` on `LocalFileSystemProvider` directly, enabling callers to query conflicts
  before triggering `.ask`-policy operations.
- **Sentinel preserved in `FileSystemLocalModule.swift`.** The smoke test at
  `Tests/FileSystemTests/Local/FileSystemLocalSmokeTests.swift` is outside the session's
  `touches:` glob. Preserving `FileSystemLocalModule.moduleName` in a dedicated file keeps
  the test green without modifying it.

---

## Concurrency boundaries

- **Actor reentrancy:** `execute` and `attributes` are actor-isolated but immediately hop to
  `Task.detached`. Concurrent calls are therefore NOT serialised by the actor — callers must
  not assume ordering across concurrent `execute` invocations.
- **Cancellation:**
  - `enumerate` streams check `Task.isCancelled` between yields in the detached enumerator.
    Breaking the `for await` loop cancels the underlying detached task via `onTermination`.
  - `FSEventsWatcher`: `continuation.onTermination` stops, invalidates, and releases the
    `FSEventStreamRef`. No additional cleanup is needed.
  - `VolumeDiscovery`: the DA session is held by the actor; continuations are removed via
    `onTermination`. The DA session itself is not explicitly torn down on actor deinit (safe
    — macOS cleans up sessions on process exit; full cleanup would require a dedicated
    `stop()` API, deferred to a later session).

## Supported `OperationKind` cases

`.copy`, `.move`, `.delete`, `.rename`, `.mkdir`, `.symlink`, `.trash`.

`.archive` and `.extract` throw `StevedoreError.unsupported(...)` — these belong to Session 05.

## Known macOS quirks

- **APFS clone-on-write:** `FileManager.copyItem` on APFS performs a lightweight clone.
  Reported `bytesProcessed` is set from `fileSize` key before the copy; the actual I/O is
  near-zero for clones.
- **Case-insensitive HFS+:** Rename from `foo` to `FOO` on a case-insensitive volume is a
  no-op at the FS level. The operation completes without error; callers must account for this.
- **`.DS_Store`:** Treated as a hidden file. `includesHiddenFiles: false` suppresses it via
  `FileManager.DirectoryEnumerationOptions.skipsHiddenFiles`.
- **`trashItem` returns the trashed URL** via the `resultingItemURL` out-parameter. We
  discard it in the current implementation; Session 10 can use it to offer "Undo Trash".
- **`isSymbolicLink` via `URLResourceValues`:** Correctly reports `true` for symlinks to
  directories, enabling `skipDescendants()` in the enumerator.

---

## Open issues / risks

1. **`.archive`/`.extract` deferred to Session 05** (`FileSystemArchive`). Currently throw
   `.unsupported`.
2. **Sandbox entitlement integration not tested.** `SecurityScopedBookmarks` falls back to
   plain bookmarks when the `com.apple.security.files.bookmarks.app-scope` entitlement is
   absent. Full sandboxed path exercised at integration time (Session 26/28).
3. **Mount/unmount integration tests stubbed.** `VolumeDiscoveryTests` asserts stream
   installation/removal but does not mount/unmount a disk image. CI-safe disk image fixtures
   can be added in a later session.
4. **DA session not explicitly torn down on actor deinit.** Safe for now but a `stop()` API
   on `VolumeDiscovery` would be cleaner for long-running apps.
5. **`detectConflicts` does not check `.destinationReadOnly`.** The `Reason` case exists but
   is never returned; checking write permission requires an `access(2)` call or a trial
   write, which was omitted for simplicity. Session 10 can add this when wiring into the
   transfers UI.

---

## Next-session inputs

Sessions that depend on Session 03 should read:

- `Sources/FileSystem/Local/LocalFileSystemProvider.swift` — provider entry point; `public
  actor` with `detectConflicts(for:)` preflight.
- `Sources/FileSystem/Local/ConflictDescriptor.swift` — conflict metadata type consumed by
  Session 10's operations engine.
- `Sources/FileSystem/Local/FSEventsWatcher.swift` — change stream consumed by UI pane
  refresh sessions (16+).
- `Sources/FileSystem/Local/VolumeDiscovery.swift` — volume stream consumed by sidebar
  session (15).
- `Tests/FileSystemTests/LocalTests/Conformance.swift` — `ProviderConformanceTests` base
  class; remote / archive sessions subclass `makeProvider()` to reuse the same scenario
  battery.

---

## Verification

All commands run from the worktree root.

```
swift build --target FileSystemLocal
→ Build of target: 'FileSystemLocal' complete!

swift test --filter FileSystemTests
→ Executed 77 tests, with 0 failures (0 unexpected)

swift test
→ Executed 120 tests, with 0 failures (0 unexpected)

swiftformat Sources/FileSystem/Local Tests/FileSystemTests/LocalTests --lint
→ 0/20 files require formatting

swiftlint lint --strict Sources/FileSystem/Local Tests/FileSystemTests/LocalTests
→ Found 0 violations, 0 serious in 214 files

swift build -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
→ Build complete!
```
