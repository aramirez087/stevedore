# Session 28 Handoff — CI Gate

## Scope

Final session of the Stevedore MVP epic. No new features were added. This session ran the
full quality-gate matrix, fixed two pre-existing test defects, authored the `Makefile` and
`.github/workflows/ci.yml`, and produced the go/no-go report at `docs/ci-report.md`.

## What changed

### New files
- **`Makefile`** — convenience targets: `format-check`, `lint`, `build`, `test`, `app`, `ci`.
  `make ci` is the aggregate target that runs the full matrix.
- **`.github/workflows/ci.yml`** — GitHub Actions workflow on `macos-14` runner; caches
  `.build` keyed by `Package.resolved`; uploads xcresult artifacts on failure.
- **`docs/ci-report.md`** — matrix results, fixes, entitlements audit, open issues, GO verdict.
- **`docs/roadmap/stevedore-mvp/session-28-handoff.md`** — this file.

### Fixed files
- **`Tests/FeaturesTests/UninstallerTests/UninstallExecutorTests.swift`** — replaced hardcoded
  absolute path to Session 25 worktree with `#filePath`-derived path (4×
  `deletingLastPathComponent()` to reach package root). Origin: Session 25.
- **`Tests/UITests/SidebarTests/SidebarViewModelTests.swift`** — replaced
  `Task.yield() × 2` with `Task.sleep(for: .milliseconds(50))` in both
  `testMountedEventAddsVolume` and `testUnmountedEventRemovesVolume`. Origin: Session 18.

## Decisions

- **`make ci` uses `swift build` (not `xcodebuild`) for the SPM build step.** `swift build`
  implicitly resolves dependencies, so a separate `swift package resolve` target is not needed.
  The CI YAML runs resolve as a separate pre-warm step before `make ci` to populate the cache.
- **`-derivedDataPath .build/DerivedData` in the Makefile.** Co-locates Xcode DerivedData
  with the SPM `.build` directory so the GitHub Actions cache covers both with one path glob.
- **50 ms sleep replaces double `Task.yield()`.** Provides a 5× margin over typical async
  propagation latency; adds ~100 ms total to the test suite.
- **`#filePath` for test portability.** `#filePath` (Swift 5.3+, preferred over `#file`)
  expands to the test source file's absolute path at compile time. Four
  `deletingLastPathComponent()` calls navigate: file → `UninstallerTests/` → `FeaturesTests/`
  → `Tests/` → package root.

## Open issues / risks

1. **Sessions 16, 17, 20, 21, 22 never implemented** — `UIPane`, `UITabs`, `UITransfers`,
   `UISyncDialog`, `UIRenameDialog` are placeholder modules. The file-list view, tab strip,
   transfer panel UI, sync dialog, and rename dialog are post-MVP.
2. **Dialog sheets are `Text(...)` placeholders** in `MainWindowView.swift`. Full
   `ConnectDialog`, `UninstallerSheet`, `SyncDialog`, and `RenameDialog` wiring deferred.
3. **`openInTerminal`** passes `""` as preferred terminal bundle ID; not wired to
   `Settings.defaultTerminalApp`.
4. **`detectConflicts` missing `.destinationReadOnly`** check (Session 03 open issue #5).
5. **`KeychainCredentialStoreTests`** may be skipped on locked-keychain headless CI agents.
6. **DA session `stop()` API absent** on `VolumeDiscovery` (Session 03 open issue #4).

## Next-session inputs

There is no next session in this epic. Post-MVP work should:

1. Read `docs/ci-report.md` for the current open-issues list.
2. Implement the missing sessions (16, 17, 20, 21, 22) for a complete feature-equivalent
   ForkLift clone.
3. Wire `Settings.defaultTerminalApp` to `OpenInTerminal.launch`.
4. Replace dialog-sheet placeholders in `MainWindowView.swift` with real `ConnectDialog`,
   `UninstallerSheet`, `UISyncDialog`, and `UIRenameDialog` instances.
5. Add `XCTSkipIf(!keychainAvailable)` guard to `KeychainCredentialStoreTests` for CI.

## Verification

All commands run from the worktree root on 2026-05-03.

```
swiftformat Sources Tests App Package.swift --lint
→ 0/412 files require formatting

swiftlint --strict
→ Found 0 violations, 0 serious in 412 files

swift package resolve
→ exits 0; Package.resolved unchanged

swift build -Xswiftc -warnings-as-errors
→ Build complete! (0 warnings, 0 errors)

swift test --parallel
→ 977 tests, 0 failures

xcodebuild -scheme Stevedore -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath .build/DerivedData clean build CODE_SIGNING_ALLOWED=NO
→ ** BUILD SUCCEEDED **

make ci
→ exits 0

xcodebuild -scheme Stevedore -destination 'platform=macOS,arch=arm64' \
    archive -archivePath /tmp/Stevedore.xcarchive -derivedDataPath .build/DerivedData \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SKIP_INSTALL=NO
→ ** ARCHIVE SUCCEEDED **
```
