# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-05-01

## User Preferences

<!-- How the user likes things done. Code style, tools, patterns, communication. -->

## Key Learnings

- **Project:** Stevedore
- **SwiftUI List selection with .tag() inside containers:** When a List row contains multiple subviews (e.g., HStack with row + button), the `.tag()` modifier must be on the outermost container (the HStack), not on a child view inside it. Otherwise, only the child view becomes selectable, not the entire row. This affects both click target and selection binding updates.
- **SwiftFormat `--lint` argument order (0.59 bug):** Pass paths BEFORE `--lint` flag: `swiftformat <paths> --lint`, not `swiftformat --lint <paths>`.
- **`ByteCountFormatter` has no `locale` property on macOS:** The property does not exist in the public API. Store locale in wrapper but don't apply it; test against a reference formatter with same countStyle.
- **`TimeZone.gmt` vs `TimeZone(secondsFromGMT:)`:** On macOS 26 SDK, `TimeZone(secondsFromGMT:)` returns `TimeZone?` (optional). Use `TimeZone.gmt` (macOS 13+, non-optional) in tests to stay warning-clean.
- **`AsyncSequence<Element, Failure>` constrained existential is macOS 15+ only:** Always return `AsyncThrowingStream<Output, any Error>` for async sequence operators targeting macOS 14.
- **`FilePath.relative(to:)` nil vs empty distinction:** Returns `[]` when `self == base` (same path); returns `nil` when base is not a prefix or schemes differ.
- **`withProgress` bytesDone carries item counts when byte sizes unavailable:** When `Element` is not `FileItem` or `sizeInBytes` is nil, `bytesDone` in `Progress` carries the item count, not bytes.
- **`GlobMatcher` ergonomic prefix:** Patterns without `/` are automatically prefixed with `**/`. Patterns with `/` are used as-is.
- **`StevedoreErrorBridge` lives in `Result+Helpers.swift`:** To stay within the session touch-glob without touching `Sources/Core/Errors/`.
- **SwiftLint trailing_comma config:** `.swiftlint.yml` has `trailing_comma: mandatory_comma: true` to reconcile with SwiftFormat `--commas always`.
- **PaneSession reentrancy contract:** all external navigations route via `PaneSession.navigate(to:)` → `PaneToolbarViewModel.navigate(to:)` → `onNavigate` → `PaneSession.updatePath(to:)`. `updatePath` MUST NOT call `navigate` again or the toolbar's `onNavigate` callback recurses. See `Sources/UI/MainWindow/PaneSession.swift:8-10,30-33,70-77`.
- **`PaneCommandProxy` is delivered via `@FocusedValue`:** `PaneHost.body` attaches the proxy with `.focusedValue(\.paneCommandProxy, isActive ? buildProxy() : nil)` (`Sources/UI/MainWindow/PaneHost.swift:50`). For menu-bar Commands and keyboard shortcuts to work, SwiftUI focus must live inside the active `PaneHost`'s subtree — not just `WindowState.activePaneID`. Tap-to-activate sets the custom `activePaneID` but does NOT acquire SwiftUI focus, so the proxy can resolve to `nil` and Go-menu/⌘-shortcuts no-op.
- **`mountedVolumeURLs` returns the autofs `/home` mount on macOS:** `FileManager().mountedVolumeURLs(includingResourceValuesForKeys:options: [.skipHiddenVolumes])` (`Sources/FileSystem/Local/VolumeDiscovery.swift:36-41`) includes `/System/Volumes/Data/home` with `volumeName == "home"`. UI layers must filter or relabel this entry; the user's real home is `FileManager.default.homeDirectoryForCurrentUser`.
- **`@FocusedSceneValue` property wrapper removed from macOS 26 SDK (Swift 6.2.3):** `FocusedSceneValue` is entirely absent from the macOS 26 `SwiftUI.swiftmodule`. The view modifier `.focusedSceneValue(_:_:)` still exists for writing. For reading scene-scoped values in `Commands`, use `@FocusedValue` — it reads from the same `FocusedValues` storage that `.focusedSceneValue` writes to.
- **`@FocusedValue` (reader) + `.focusedSceneValue` (emitter) is the correct pattern for macOS 26:** Emitter attaches `.focusedSceneValue(\.key, value)` on the View; consumer uses `@FocusedValue(\.key)` in Commands. This propagates the value to the menu bar regardless of keyboard focus position.
- **`PaneCommandProxy` must be emitted with `.focusedSceneValue`:** Using `.focusedValue` means the proxy is nil whenever keyboard focus is outside PaneHost (sidebar click, first launch, etc.). `.focusedSceneValue` keeps the proxy alive throughout the window scene.
- **`URLResourceMapperKeys` is the global prefetch set** (`Sources/FileSystem/Local/URLResourceMapper.swift:5-21`). It includes `.fileSecurityKey` and `.isPackageKey`, both relatively expensive. `LocalDirectoryEnumerator` requests this set in `fm.enumerator(...)` AND fetches the same keys per-item with `url.resourceValues(forKeys:)` — the second fetch duplicates the prefetch and forces an extra kernel round-trip per file (`Sources/FileSystem/Local/LocalDirectoryEnumerator.swift:58-81`).

## Do-Not-Repeat

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->

- [2026-05-03] **SPM executableTarget does NOT produce a .app bundle in Xcode.** Xcode treats it as a command-line tool; `Bundle.main.bundleIdentifier` is nil, SwiftUI's WindowGroup never shows a window, and the log says "Cannot index window tabs due to missing main bundle identifier". Fix: use `xcodegen` + `project.yml` to create a real `.xcodeproj` with `type: application`. Remove the `executableTarget` from Package.swift to avoid `@main` conflicts. Tests and library builds still work via `swift build`.
- [2026-05-03] **Frame dimension calculations in layout:** `DualPaneLayout.leftWidth()` can produce negative widths if the total available width is small or zero during initial layout. Always guard against zero/negative widths with `guard total > 0` and `max(0, calculatedValue)` to prevent "Invalid frame dimension" crashes.
- [2026-05-02] `swift test --filter SidebarTests` matches **zero** classes — none of the test class names contain that exact substring. Use `--filter Sidebar` instead, which matches all sidebar test classes (`SidebarViewModelTests`, `SidebarFavoritesSectionTests`, etc.).
- [2026-05-02] `swiftlint --path <dir>` is not a valid flag. Correct form: `swiftlint --strict <dir1> <dir2>` (positional path arguments).
- [2026-05-02] `@testable import UISidebar` is required in all sidebar test files — `start()`, `ejectVolume(url:)`, and all section views are `internal`. Plain `import UISidebar` causes "inaccessible due to 'internal' protection level" errors.
- [2026-05-02] Retain cycle pattern in `@Observable` task: capturing `let discovery = volumeDiscovery` (Sendable) and `guard let self else { break }` **inside** the `for await` loop body is correct. `guard let self else { return }` **before** the loop creates a retain cycle. Weak `self` capture plus per-iteration `guard` is the safe pattern.
- [2026-05-02] **`@Observable` `didSet` infinite recursion**: setting a stored property inside its own `didSet` always recurses. Fix: compute clamped value, `guard clamped != self.value else { return }`, then assign.
- [2026-05-02] **`Tab` ambiguous on macOS 15+**: SwiftUI adds `SwiftUI.Tab` in macOS 15. Any file importing both `Core` and `SwiftUI` must qualify as `Core.Tab`. Same pattern applies to `FeaturesOperations.Operation` vs `Foundation.Operation`.
- [2026-05-02] **`ConnectionStatus` enum cases**: only `.idle`, `.connecting`, `.connected`, `.error(String)` exist — there is NO `.disconnected` case. Use `.idle` for stub/no-op providers.
- [2026-05-02] **Test fake naming collisions in shared test target**: all `UITests` target fakes live in the same namespace. Prefix fakes with the module abbreviation (e.g. `MW` for MainWindow) to avoid "invalid redeclaration" errors when SidebarTestSupport defines the same names.
- [2026-05-02] **`swift build 2>&1 | tee file; echo "EXIT: $?"** captures `tee`'s exit code, NOT `swift build`'s. Use `swift build; echo "EXIT:$?"` (no pipe) to get the true build exit code.

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->

- [2026-05-02] **`@ObservationIgnored` on injected protocol existentials** in `SidebarViewModel`: prevents `@Observable` macro from wrapping `any BookmarksProviding` etc. in observation accessors, which would emit Swift 6 non-`Sendable` warnings.
- [2026-05-02] **`@MainActor` protocols for `BookmarksProviding`/`ConnectionStatusProviding`**: eliminates `await` at every call site from the `@MainActor` view model; both consumed only on main actor.
- [2026-05-02] **`final actor` + `nonisolated let` for `FakeVolumeDiscovery`**: allows `emit()` to be called from any context (tests run on `@MainActor`) without hop; `nonisolated let` avoids actor isolation on immutable stored properties.
- [2026-05-02] **`OSAllocatedUnfairLock` in `FakeVolumeEjector`**: `NSLock.lock()` is `@available(*, noasync)` in Swift 6. Use `OSAllocatedUnfairLock` for mutation in `@unchecked Sendable` test helpers.
