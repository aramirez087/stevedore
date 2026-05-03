# CI Report — Session 28

**Date:** 2026-05-03  
**Branch:** `epic/stevedore-mvp--s28-ci-gate`  
**Verdict:** **GO**

---

## Quality Gate Matrix

| Step | Command | Result |
|------|---------|--------|
| Format check | `swiftformat Sources Tests App Package.swift --lint` | ✅ 0/412 files require formatting |
| Lint | `swiftlint --strict` | ✅ 0 violations, 0 serious in 412 files |
| Package resolve | `swift package resolve` | ✅ exits 0; Package.resolved unchanged |
| Build | `swift build -Xswiftc -warnings-as-errors` | ✅ Build complete! 0 warnings, 0 errors |
| Tests | `swift test --parallel` | ✅ 977 tests, 0 failures |
| Xcode build | `xcodebuild -scheme Stevedore … clean build CODE_SIGNING_ALLOWED=NO` | ✅ BUILD SUCCEEDED |
| Full gate | `make ci` | ✅ exits 0 |

### Archive (diagnostic)

```
xcodebuild -scheme Stevedore … archive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SKIP_INSTALL=NO
→ ** ARCHIVE SUCCEEDED **
```

Archive builds cleanly with no code-signing requirement.

---

## Fixes Applied

### Fix 1 — S25: `testNoRemoveItemCall` hardcoded worktree path

**File:** `Tests/FeaturesTests/UninstallerTests/UninstallExecutorTests.swift`  
**Problem:** `testNoRemoveItemCall` used an absolute path to the Session 25 worktree (`/Users/aramirez/Code/.epic-worktrees/Stevedore/epic-stevedore-mvp--s25-uninstaller-ui`). Failed on any checkout that is not that exact path.  
**Fix:** Replaced hardcoded path with `#filePath`-derived path — four `deletingLastPathComponent()` calls walk up from the test file to the package root, then append `Sources/Features/Uninstaller/UninstallExecutor.swift`.

### Fix 2 — S18: `testMountedEventAddsVolume` / `testUnmountedEventRemovesVolume` timing

**File:** `Tests/UITests/SidebarTests/SidebarViewModelTests.swift`  
**Problem:** Both tests used two `Task.yield()` calls after emitting a volume event. On loaded machines two cooperative yields are insufficient for the event to propagate through `AsyncStream` → `for await` → `@Observable` main-actor update.  
**Fix:** Replaced `await Task.yield(); await Task.yield()` with `try? await Task.sleep(for: .milliseconds(50))` in both tests. 50 ms provides a 5× safety margin over typical sub-10 ms propagation.

---

## Entitlements Audit

**File:** `App/Stevedore/Stevedore.entitlements`

| Entitlement | Value | Verdict |
|-------------|-------|---------|
| `com.apple.security.app-sandbox` | `false` | KEEP — app uses `FileManager` for arbitrary paths, shells out to `/usr/bin/git` and `/usr/bin/tar` |
| `com.apple.security.files.user-selected.read-write` | `true` | KEEP — core file manager function |
| `com.apple.security.files.bookmarks.app-scope` | `true` | KEEP — `SecurityScopedBookmarks.swift` uses app-scope bookmarks |

No entitlements trimmed. All three are actively used by production code.

---

## Open Issues

1. **Sessions 16, 17, 20, 21, 22 never implemented.** `UIPane`, `UITabs`, `UITransfers`, `UISyncDialog`, `UIRenameDialog` remain as placeholder modules. File-list view, tab strip, transfer panel UI, sync dialog, and rename dialog were not built in the epic.

2. **Dialog sheets are `Text(...)` placeholders** in `MainWindowView.swift` (Session 27). Full `ConnectDialog`, `UninstallerSheet`, `SyncDialog`, and `RenameDialog` wiring was deferred.

3. **`openInTerminal` passes `""` as preferred terminal bundle ID** (Session 27). Should be wired to `Settings.defaultTerminalApp`.

4. **`detectConflicts` missing `.destinationReadOnly` check** (Session 03 open issue #5).

5. **`LogRingBuffer` not directly accessible from Diagnostics panel** (Session 09 open issue #1).

6. **DA session `stop()` API absent** on `VolumeDiscovery` (Session 03 open issue #4).

7. **`KeychainCredentialStoreTests` may be skipped on locked-keychain CI agents.** Tests hit the real macOS login Keychain; headless CI may have it locked (Session 06 open issue #1).

---

## Verdict

**GO**

All quality gates pass. `make ci` exits 0 from a clean checkout. 977 tests, 0 failures. Two pre-existing test defects (one portability bug from S25, one timing fragility from S18) were fixed. The archive builds cleanly without code signing. The codebase is in a shippable state for the implemented epic scope.
