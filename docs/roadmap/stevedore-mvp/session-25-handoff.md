# Session 25 Handoff — Uninstaller UI

## Scope

Absorbed Session 15's engine scope (FeaturesUninstaller) and built the full Uninstaller UI
(UIUninstallerUI): engine types, protocols, concrete actors, testing fakes, all five SwiftUI
views, ViewModel, and 32 tests covering every exit criterion.

## What changed

### `Sources/Features/Uninstaller/` — engine (new)
- `FeaturesUninstallerModule.swift` — module sentinel (replaces Placeholder.swift)
- `Confidence.swift` — `Comparable` enum; `from(score:)` maps 0.7+→high, 0.4+→medium, else low
- `AppMetadata.swift` — bundle introspection value type (bundleURL, bundleID, bundleName, executableName, version?, bundleSizeInBytes)
- `AssociatedFile.swift` — `Identifiable` candidate file (url, sizeInBytes, lastModified, confidence, reason, requiresAdmin)
- `UninstallPlan.swift` — aggregates metadata + selectedFiles; `totalBytes` computed
- `UninstallerError.swift` — `.notAnAppBundle`, `.invalidInfoPlist`, `.trashFailed`
- `SearchPaths.swift` — `userPaths` (10 `~/Library/` subdirs), `systemPaths` (5 `/Library/` subdirs), `isSystemOwned(_:)`
- `Protocols/AppMetadataReading.swift`, `Protocols/AssociatedFilesScanning.swift`, `Protocols/UninstallExecuting.swift`
- `AppMetadataReader.swift` — `struct`; reads `Contents/Info.plist`, computes bundle size via `FileManager.enumerator`
- `MatchScorer.swift` — pure scoring: bundleID last component (≥4 chars, score 0.9), bundleName (≥3 chars, 0.7), executableName (≥3 chars, 0.5), catch-all 0.1 (excluded)
- `AssociatedFilesScanner.swift` — `actor`; injectable `userSearchPaths`/`systemSearchPaths`; top-level dir walk; files from systemSearchPaths flagged `requiresAdmin: true`
- `UninstallExecutor.swift` — `actor`; `trashItem` exclusively; skips `requiresAdmin` files; trashes selected files then bundle
- `Testing/FakeAppMetadataReader.swift`, `Testing/FakeAssociatedFilesScanner.swift`, `Testing/FakeUninstallExecutor.swift` — production-target fakes; `FakeUninstallExecutor` uses `OSAllocatedUnfairLock`

### `Sources/UI/UninstallerUI/` — views (new)
- `UIUninstallerUIModule.swift` — module sentinel (replaces Placeholder.swift)
- `ScanState.swift` — file-scope enum (idle/scanning/ready/failed)
- `AssociatedFileSortKey.swift` — file-scope sort key enum (path/size/modified/confidence)
- `UninstallerViewModel.swift` — `@MainActor @Observable`; `load(appURL:) async` runs inline (awaitable by tests); `@ObservationIgnored` on injected deps
- `AppHeader.swift` — app icon via `NSWorkspace`, name, version, size
- `AssociatedFilesTable.swift` — SwiftUI `Table` with checkbox column, lock icon for requiresAdmin, confidence badge, low-confidence toggle
- `ConfirmationFooter.swift` — Cancel + destructive SDButton pair
- `UninstallerSheet.swift` — root sheet; switches on `ScanState`; `ContentUnavailableView` for failures
- `UninstallerLauncher.swift` — idle drop target; `dropDestination(for: URL.self)`; inline error display

### `Tests/FeaturesTests/UninstallerTests/` (new)
- `UninstallerTestSupport.swift`, `AppMetadataReaderTests.swift`, `MatchScorerTests.swift`, `AssociatedFilesScannerTests.swift`, `UninstallExecutorTests.swift`

### `Tests/UITests/UninstallerUITests/` (new)
- `UninstallerViewModelTests.swift`, `UninstallerSheetTests.swift`

### `Package.swift` (modified)
- `UIUninstallerUI` extra deps: `DesignSystem`, `FeaturesUninstaller`
- `UITests` extra dep: `FeaturesUninstaller` (for fakes)

### `docs/roadmap/stevedore-mvp/session-25-handoff.md` (this file)

## Decisions

- **`load(appURL:)` runs inline (no background Task).** The function is already `async`; callers that want non-blocking behaviour wrap it in `Task { await vm.load(appURL:) }` (UninstallerLauncher does this). Inline execution makes the function trivially awaitable in unit tests without polling.
- **`AssociatedFilesScanner` has injectable search paths.** `init(userSearchPaths:systemSearchPaths:)` defaults to `SearchPaths.userPaths`/`systemPaths`; tests inject temp directories. `requiresAdmin` is determined by which set the file came from, not by URL prefix.
- **Engine absorbed here (not Session 15).** Session 15 was never executed; this session delivers both engine and UI. Session 28 should include `swift build --target FeaturesUninstaller` in its CI gate.
- **`@ObservationIgnored` on all injected protocol deps.** Prevents `@Observable` macro from wrapping `any AppMetadataReading` etc. in observation accessors, which emits Swift 6 non-Sendable warnings.
- **`FakeUninstallExecutor` uses `OSAllocatedUnfairLock`.** `NSLock.lock()` is `@available(*, noasync)` in Swift 6.
- **`UninstallPlan` and `AppMetadata` have explicit `public init`.** Swift synthesises memberwise inits as `internal`; without explicit `public` the ViewModel and UI tests cannot construct instances.

## Drop-target convention

`UninstallerLauncher` accepts `.fileURL` drops via `dropDestination(for: URL.self)` and calls:
```swift
Task { await self.viewModel.load(appURL: url) }
```
Validation lives entirely in `UninstallerViewModel.load(appURL:)`:
1. `pathExtension == "app"` — else sets `dropError`, stays `.idle`
2. `Contents/Info.plist` exists — else sets `dropError`, stays `.idle`
3. Both pass → `.scanning` → async read + scan → `.ready` or `.failed`

## Default selection rules

After scan completes, `applyDefaultSelections` is called:
- **Checked by default:** `confidence == .high` AND `!requiresAdmin`
- **Unchecked (visible):** `confidence == .medium`
- **Hidden (collapsed):** `confidence == .low` — revealed by `showLowConfidence = true` toggle

## System-path policy

Files from `systemSearchPaths` are returned with `requiresAdmin: true`. In the UI:
- Toggle is `.disabled(row.requiresAdmin)` — cannot be checked even with keyboard
- `toggleSelection(_:)` in ViewModel no-ops when `file.requiresAdmin`
- `UninstallExecutor.execute` skips `requiresAdmin` files silently
- Files are still shown (with a lock icon) for user information

## Engine handshake for Session 26

```swift
let vm = UninstallerViewModel(
    metadataReader: AppMetadataReader(),
    scanner: AssociatedFilesScanner(),
    executor: UninstallExecutor()
)
// Present as sheet:
UninstallerSheet(viewModel: vm, onDismiss: { sheet.dismiss() })
```

Or drop any `.app` URL onto `UninstallerLauncher(viewModel: vm)`.

## Open issues / risks

1. **Pre-existing `SidebarViewModelTests` flakiness** (`testMountedEventAddsVolume`, `testUnmountedEventRemovesVolume`) — timing-based async tests from session 18; not introduced here.
2. **`UninstallExecutor` uses real `FileManager.trashItem`.** Tests that exercise the executor create actual temp files; test teardown removes them. Tests that pass non-existent paths correctly receive `.trashFailed`.
3. **No admin-path escalation.** `requiresAdmin` files are shown but never trashed. Future session could add AppleScript-based privileged trash for system files.
4. **`load(appURL:)` is sequential** — if the user drops a second app before the first scan completes, `cancel()` then `load()` again is the caller's responsibility. The UI does not auto-cancel.

## Next-session inputs

- `Sources/Features/Uninstaller/` — all engine types, protocols, and fakes
- `Sources/UI/UninstallerUI/` — all views; sheet entry point is `UninstallerSheet(viewModel:onDismiss:)`
- `Sources/Features/Uninstaller/Testing/` — fakes importable from any test target (production target)
- This handoff, especially the drop-target convention, default selection rules, and system-path policy sections

## Verification

```
swift build --target FeaturesUninstaller -Xswiftc -warnings-as-errors
→ Build of target 'FeaturesUninstaller' complete! (37.23s)

swift build --target UIUninstallerUI -Xswiftc -warnings-as-errors
→ Build of target 'UIUninstallerUI' complete! (13.07s)

swift build -Xswiftc -warnings-as-errors
→ Build complete! (9.17s)

swift test --filter "AppMetadataReaderTests|MatchScorerTests|AssociatedFilesScannerTests|UninstallExecutorTests"
→ Executed 18 tests, with 0 failures

swift test --filter "UninstallerViewModelTests|UninstallerSheetTests"
→ Executed 14 tests, with 0 failures

swift test (full suite)
→ Executed 934 tests, with 1 failure (pre-existing SidebarViewModelTests flake, unrelated to this session)

swiftformat Sources/UI/UninstallerUI Tests/UITests/UninstallerUITests Sources/Features/Uninstaller Tests/FeaturesTests/UninstallerTests --lint
→ 0/33 files require formatting

swiftlint --strict Sources/UI/UninstallerUI Sources/Features/Uninstaller
→ Found 0 violations, 0 serious
```
