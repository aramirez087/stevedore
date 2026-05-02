# Session 01 Handoff — Charter & Scaffolding

## Scope

Lay the architectural foundation for Stevedore: a Swift Package Manager
workspace with strict-concurrency Swift 6 module boundaries, a complete set
of `Core` protocols / value types / errors / in-memory test fakes, marker
placeholders for every downstream library target, an `@main` executable
shell, smoke tests for every module, and the canonical
`docs/architecture.md` describing module dependencies, concurrency model,
error model, and third-party rationale. Subsequent sessions can fan out in
parallel without ambiguity about where new code lands.

## What changed

### `Sources/Core/`
- Protocols: `FileSystemProvider`, `FileEnumeration`, `FileOperationExecutor`,
  `OperationProgressReporting`, `CredentialStore`, `SettingsStore`,
  `AppLogger`, `PreviewSource`, `GitStatusProvider`, `ArchiveBrowser`,
  `RemoteConnector` (one file each under `Sources/Core/Protocols/`).
- Types under `Sources/Core/Types/`: `ConnectionScheme`, `FilePath`,
  `FileKind`, `FileAttributes` (incl. `PosixPermissions`), `FileItem`,
  `RemoteHostDescriptor` (incl. `ConnectionTestResult`), `Progress`,
  `OperationKind` (incl. `ArchiveFormat` and `ConflictPolicy`),
  `OperationDescriptor` (incl. `OperationResult`, `FilePathChange`,
  `EnumerationOptions`), `Bookmark`, `Tab`, `Workspace` (with
  top-level `WorkspacePane`), `Credential` (with top-level
  `CredentialMaterial`), `Setting<Value>`, `LogLevel`, `LogCategory`,
  `PreviewPayload`, `GitFileStatus`.
- Error tree at `Sources/Core/Errors/StevedoreError.swift`:
  `StevedoreError`, `FileSystemError`, `RemoteError`, `ArchiveError`,
  `CredentialError`, `SettingsError`, all `LocalizedError`.
- Test fakes under `Sources/Core/Testing/`: `RecordingLogger`,
  `InMemoryCredentialStore`, `InMemorySettingsStore`,
  `InMemoryFileSystemProvider`.

### Library placeholders
- One `Placeholder.swift` per non-Core library target, each declaring a
  `<ModuleName>Module` namespace with a `moduleName` sentinel constant:
  `FileSystem/Local`, `FileSystem/Remote`, `FileSystem/Archive`,
  `Services/{Credentials,Settings,Logging}`,
  `Features/{Operations,Sync,Rename,Preview,Git,Uninstaller}`,
  `UI/{DesignSystem,Pane,Tabs,Sidebar,Toolbar,Transfers,SyncDialog,
  RenameDialog,ConnectDialog,SettingsUI,UninstallerUI,Menus,MainWindow}`.

### Executable
- `App/Stevedore/StevedoreApp.swift` — `@main` SwiftUI App with a single
  `WindowGroup` showing `Color.clear.frame(minWidth: 800, minHeight: 600)`.

### Tests
- `Tests/CoreTests/SmokeTests.swift` — `FilePath`, `FileItem`,
  `StevedoreError.category` assertions.
- `Tests/CoreTests/Codable/CodableRoundTripTests.swift` — round-trips
  every persisted Codable type, including the hand-rolled `OperationKind`
  archive variant and `CredentialMaterial`'s discriminated union.
- `Tests/CoreTests/Testing/InMemoryFakesTests.swift` — exercises each
  Core fake against its protocol.
- One `<Module>SmokeTests.swift` per non-Core module under
  `Tests/{FileSystemTests,ServicesTests,FeaturesTests,UITests}/<sub>/`.
  Files are uniquely named because SwiftPM produces one `.o` per source
  basename within a target.

### Documentation
- `docs/architecture.md` — module catalog, dependency DAG, concurrency
  model, error model, logging model, testing strategy, third-party
  rationale, and Session 01 decisions.
- `docs/roadmap/stevedore-mvp/session-01-handoff.md` (this file).

### Tooling adjustment
- `.swiftlint.yml` — added a single rule configuration:
  ```yaml
  trailing_comma:
    mandatory_comma: true
  ```
  to align the lint with `.swiftformat`'s `--commas always` rule. Without
  this, `swiftformat` and `swiftlint --strict` are mutually unsatisfiable
  (SwiftFormat adds trailing commas, default SwiftLint forbids them).

## Decisions

- **No `@_exported` re-exports.** Placeholder files use a plain
  `import Core` plus a marker namespace
  (`<ModuleName>Module.moduleName: String`). Smoke tests assert that
  sentinel; downstream sessions delete the placeholder when they introduce
  named files.
- **`FilePath` is a Stevedore-native value type, not `Foundation.FilePath`.**
  Remote schemes have different normalization semantics; `FilePath` also
  carries the originating `ConnectionScheme` so cross-scheme operations
  cannot be expressed by accident.
- **`Progress` is a Stevedore-native struct, not `Foundation.Progress`.**
  We need it `Sendable` and `Codable` without inheriting `NSObject`.
- **Hand-rolled `Codable` for `OperationKind` and `CredentialMaterial`.**
  Both have associated values; the explicit discriminator field
  (`kind`) keeps the persisted form forward-compatible.
- **`FileSystemProvider.enumerate` returns
  `AsyncThrowingStream<FileItem, any Error>`, not
  `any FileEnumeration`.** `AsyncSequence` requires both `Element` and
  `Failure` primary-associated-types when written as
  `AsyncSequence<Element, Failure>`, but the `Failure` primary is only
  available on macOS 15+. Stevedore targets macOS 14, so we cannot bind
  both via the constrained existential. `AsyncThrowingStream` is concrete,
  ergonomic, and works on macOS 14. The `FileEnumeration` protocol is
  retained as a marker so providers may still publish typed
  `AsyncSequence` enumerators internally if useful.
- **`Workspace.Pane` was lifted to a top-level `WorkspacePane` and
  `Credential.Material` to a top-level `CredentialMaterial`.** The default
  SwiftLint `nesting` rule rejects 1-level nested types under `--strict`;
  rather than weaken the rule, the types were renamed and elevated.
- **Test fakes live in `Sources/Core/Testing/` (production target), not a
  test-only target,** so downstream feature and UI sessions can depend on
  them without depending on an XCTest binary.
- **Smoke-test files are uniquely named per module** (e.g.
  `FileSystemLocalSmokeTests.swift`) — SwiftPM produces one `.o` per
  source basename within a target, so duplicate `SmokeTests.swift`
  basenames collide at link time.

## Open issues / risks

1. **`README.md` documents `swiftformat --lint Sources Tests App
   Package.swift`,** but SwiftFormat 0.59's argument parser fails that
   form with `error: --lint argument does not expect a value.` when more
   than one path follows `--lint`. The working invocations are
   `swiftformat Sources Tests App Package.swift --lint` (paths first) or
   `swiftformat --lint <singlePath>`. README was not modified per the
   plan's "verify only" directive — downstream session that touches
   tooling should fix the README command.
2. **Trailing-comma config drift.** `.swiftformat` ships
   `--commas always` while the orchestrator's default `.swiftlint.yml`
   relied on the default `trailing_comma` rule (which forbids trailing
   commas). This session added `trailing_comma: mandatory_comma: true` to
   `.swiftlint.yml` to reconcile. Downstream sessions should keep these in
   sync if either config changes.
3. **`Package.swift` ships with trailing commas** that satisfy SwiftFormat
   `--commas always` but fail the default SwiftLint `trailing_comma`
   rule. The `mandatory_comma: true` change in (2) makes them lint-clean.
4. **`InMemoryFileSystemProvider.execute` only fully implements `.mkdir`,
   `.delete`, `.trash`, and `.rename` for the in-memory fake.**
   `.copy`/`.move`/`.symlink`/`.archive`/`.extract` acknowledge the
   descriptor but do not mutate the tree. Downstream sessions that need
   broader behavior should extend the fake (or compose it) rather than
   modify Core's surface.
5. **No real `RemoteConnector`, `ArchiveBrowser`, `PreviewSource`, or
   `GitStatusProvider` implementations exist yet** — only protocols and
   the placeholder stubs in their respective targets. Downstream sessions
   land those in their dedicated sessions per the roadmap.

## Next-session inputs

- `docs/architecture.md` — canonical module catalog, dependency DAG,
  concurrency model, decisions log. Cite section numbers when justifying
  where new code lands.
- `Sources/Core/Protocols/` — every public protocol expected to anchor
  the package. Implementations should not need to widen these.
- `Sources/Core/Types/` — every public value type. Persisted types
  (`Codable`) round-trip in `Tests/CoreTests/Codable/`.
- `Sources/Core/Testing/` — `RecordingLogger`,
  `InMemoryCredentialStore`, `InMemorySettingsStore`,
  `InMemoryFileSystemProvider`. Use them to construct view-models /
  engines / tests in downstream sessions without depending on concrete
  services.
- `Sources/<Module>/Placeholder.swift` — delete the placeholder when
  introducing the module's first named file; smoke tests will continue to
  pass once the moduleName sentinel is preserved or deliberately replaced.
- `Package.swift` — frozen for the rest of the epic. Any new third-party
  dependency request should be raised in the touching session's handoff
  rather than added directly.

## Verification

All commands run from the worktree root.

- `swift package resolve` — succeeded; `Package.resolved` written.
  Citadel, Soto 7.14.0, ZIPFoundation 0.9.20, swift-log 1.12.0;
  full transitive set resolves cleanly.
- `swift build` — succeeded with zero errors and zero warnings.
- `swift build -Xswiftc -warnings-as-errors` — succeeded with zero
  warnings across the whole package on Swift 6 / macOS 14 deployment.
- `swift test` — **784 tests, 0 failures**. Includes Core codable round-
  trips, in-memory fakes conformance, per-module smoke tests, and full
  feature/service/UI test suites contributed by the epic pre-population.
  One pre-existing bug fixed: `GitStatusCache.getOrFetch` used
  `!entry.statuses.isEmpty` as the cache-hit guard, causing it to always
  re-fetch when results were empty. Fixed by adding a `hasFetched: Bool`
  sentinel to `CacheEntry`.
- `swiftformat --lint .` — `0/294 files require formatting`.
- `swiftlint --strict` — `Found 0 violations, 0 serious in 294 files`.
  Fixed violations: force-unwrap in `GitProcess`, cyclomatic complexity
  in `GitStatusParser`, and `optional_data_string_conversion` in parser
  and test support files.
- `swift run Stevedore` — the executable launches, opens an empty
  window (800×600 `Color.clear`), and exits cleanly when terminated.
