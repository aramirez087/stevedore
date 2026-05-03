# Session 13 Handoff — Preview Service (Quick Look)

## Scope

Implement the full preview pipeline for Stevedore: a `PreviewService` actor that dispatches file items to first-party renderers (text, code, image) or falls back to `QLThumbnailGenerator`; an `NSCache`-backed `PreviewCache` with a configurable byte limit; a `ThumbnailGenerator` actor that coalesces concurrent QL requests; and a `QuickLookPanelController` `@MainActor` class for spacebar-preview. All code is under Swift 6 strict concurrency.

## What changed

### `Sources/Features/Preview/` (new files)

- **`FeaturesPreviewModule.swift`** — Replaces `Placeholder.swift`; preserves `FeaturesPreviewModule.moduleName = "FeaturesPreview"` sentinel for the existing smoke test.
- **`PreviewCache.swift`** — `public actor PreviewCache` wrapping `NSCache<NSString, CachedPreview>`; byte-limited via `NSCache.totalCostLimit`; `CachedPreview: NSObject` stores payload and reports `cost = data.count`. Default limit 50 MB.
- **`ThumbnailGenerator.swift`** — `public actor ThumbnailGenerator`; coalesces concurrent requests for the same (url, size) key via a `[String: Task<Data?, any Error>]` inflight dict; bridges `QLThumbnailGenerator.generateBestRepresentation(for:completion:)` to async via `withCheckedThrowingContinuation`; returns PNG `Data` built from `CGImage` (avoids `@MainActor` `NSImage` in callback).
- **`QuickLookPanelController.swift`** — `@MainActor public final class QuickLookPanelController: NSObject`; implements `QLPreviewPanelDataSource` and `QLPreviewPanelDelegate`; `show(urls:)`, `toggle(urls:)`, `close()` API; protocol stubs use `nonisolated` + `MainActor.assumeIsolated` since AppKit always calls them on main.
- **`PreviewService.swift`** — `public actor PreviewService: PreviewSource`; renderer dispatch order: (1) image extensions → `ImagePreviewRenderer`, (2) code extensions → `CodePreviewRenderer`, (3) text extensions → `TextPreviewRenderer`, (4) magic-byte sniff (no null bytes in first 4 KB) → `TextPreviewRenderer`, (5) fallback → `ThumbnailGenerator`; caches results in `PreviewCache`. QL fallback uses `try?` so QL errors (unsupported file type) return `nil` instead of throwing.

### `Sources/Features/Preview/Renderers/` (new files)

- **`TextPreviewRenderer.swift`** — `public enum` namespace; reads ≤1 MB via `Task.detached`; detects encoding from BOM (UTF-16 BE/LE, UTF-8) then UTF-8 then Latin-1 fallback; returns RTF `Data` via `NSAttributedString`.
- **`ImagePreviewRenderer.swift`** — `public enum` namespace; decodes `NSImage(contentsOf:)` in `Task.detached`; resamples to fit `maxDimension` (scale capped at 1.0 to prevent upscaling); returns PNG `Data`.
- **`CodePreviewRenderer.swift`** — `public enum` namespace; `Language` enum at file scope (avoids SwiftLint `nesting` rule); extension→language and language→keywords as file-scope dictionaries (avoids cyclomatic complexity violations from switch statements); regex-based token coloring (keywords=blue, strings=red, comments=green, numbers=purple) using `NSRegularExpression` + `NSMutableAttributedString`; returns RTF `Data`.

### `Tests/FeaturesTests/PreviewTests/` (new directory + 7 files)

- `PreviewTestSupport.swift`, `PreviewCacheTests.swift`, `TextPreviewRendererTests.swift`, `ImagePreviewRendererTests.swift`, `CodePreviewRendererTests.swift`, `ThumbnailGeneratorTests.swift`, `PreviewServiceTests.swift`

### Deleted

- `Sources/Features/Preview/Placeholder.swift`

## Decisions

- **`Language` at file scope, not nested in `CodePreviewRenderer`** — SwiftLint `nesting` rule rejects nested enum-in-enum; placing `Language` at module scope (no `public`) allows `@testable import` from tests while keeping the module-internal interface clean.
- **Dictionary lookups instead of switches for `Language` mapping** — Switches with 20 cases exceed SwiftLint's `cyclomatic_complexity` warning threshold (12) which becomes an error under `--strict`. Replacing both the extension→language and language→keywords switches with static dictionary literals keeps all function bodies at complexity ≤ 2.
- **`CGImage` instead of `NSImage` in QL callback** — `NSImage` may carry `@MainActor` annotations in Swift 6 SDK; accessing it inside a `withCheckedThrowingContinuation` callback (arbitrary thread) would be a concurrency violation. `CGImage` is `Sendable` and available from `QLThumbnailRepresentation.cgImage`; `NSBitmapImageRep(cgImage:)` converts to PNG without requiring the main actor.
- **Renderers are non-throwing** — All file I/O in renderers uses `try?`; the functions return `PreviewPayload?` (nil on any failure) rather than throwing. This simplifies call sites and keeps `PreviewService.preview(for:)` errors limited to QL thumbnail failures (which are also suppressed with `try?` in the final dispatch branch).
- **QL fallback uses `try?`** — `QLThumbnailGenerator` throws domain errors for unsupported file types (e.g. `.bin` files with null bytes). Using `try?` in `PreviewService.dispatch`'s fallback branch normalizes these to `nil` rather than propagating an error to callers.
- **Off-main-actor enforcement is structural** — `PreviewService` is a plain `actor` (not `@MainActor`). The test `testPreviewRunsOffMainActor` confirms calls complete from `Task.detached` context (never on main actor). `Thread.isMainThread` is unavailable in async contexts on macOS 26 SDK; the structural guarantee via the `actor` keyword is the enforceable invariant.
- **`@testable import FeaturesPreview`** — `Language`, `ImagePreviewRenderer.resample`, and `TextPreviewRenderer.detectAndDecode` are module-internal (`internal`) helper types/methods. Tests use `@testable import` rather than making them `public`, preserving encapsulation.

## Open issues / risks

1. **`QuickLookPanelController` not tested in headless CI** — `QLPreviewPanel.shared()` returns `nil` without a display connection. The `toggle`/`show`/`close` API is covered by code review but not a passing automated test. Session 26 (MainWindow) should add an integration test when a display is available.
2. **`NSBitmapImageRep(cgImage:)` concurrency** — If a future SDK annotates `NSBitmapImageRep` as `@MainActor`, the QL thumbnail generation pipeline will need to dispatch PNG conversion to the main actor or use `ImageIO` (`CGImageDestination`) instead.
3. **Code renderer regex performance on large files** — The keyword regex is rebuilt per-render call (not cached). For files approaching the 512 KB read limit with dense keyword density, compiling a regex with ~50 alternations may add latency. Cache `NSRegularExpression` per language if benchmarking reveals this as a bottleneck.
4. **Magic-byte text detection is heuristic** — Null-byte sniff in first 4 KB works for common binary formats but can misclassify binary formats that happen to have a null-free header (e.g. some compressed formats). The fallback to QL handles these gracefully.
5. **`NSCache` eviction is advisory** — `NSCache` with `totalCostLimit` evicts under memory pressure but not necessarily immediately when the limit is exceeded. The burst-1000 test documents this behavior and asserts "no crash" rather than strict cap enforcement.

## Next-session inputs

Sessions 16 (UIPane) and 26 (MainWindow) should read:

- `Sources/Features/Preview/PreviewService.swift` — `PreviewSource` conformance; `thumbnail(for:size:)` returns `Data?` (PNG); `preview(for:item:)` returns `PreviewPayload?` (`mimeType` is either `"text/rtf"` or `"image/png"`).
- `Sources/Features/Preview/QuickLookPanelController.swift` — `@MainActor` controller for spacebar-preview; call `toggle(urls:)` on spacebar key event.
- Non-obvious: `PreviewService.preview(for:)` never throws for local files (QL errors suppressed); it can throw if `ThumbnailGenerator` encounters a cancellation during the thumbnail call.
- Non-obvious: `Language` type is in `Sources/Features/Preview/Renderers/CodePreviewRenderer.swift` at file scope (not inside `CodePreviewRenderer`); tests use `@testable import FeaturesPreview` to access it.

## Verification

```
swift build --target FeaturesPreview
→ Build of target: 'FeaturesPreview' complete! (0 warnings)

swift test --filter "PreviewCacheTests|TextPreviewRendererTests|ImagePreviewRendererTests|CodePreviewRendererTests|ThumbnailGeneratorTests|PreviewServiceTests|FeaturesPreviewSmokeTests"
→ Executed 49 tests, with 0 failures (0 unexpected)

swiftformat Sources/Features/Preview Tests/FeaturesTests/PreviewTests --lint
→ 0/15 files require formatting

swiftlint lint --strict Sources/Features/Preview Tests/FeaturesTests/PreviewTests
→ Done linting! Found 0 violations, 0 serious in 564 files.

swift build -Xswiftc -warnings-as-errors
→ Build complete! (0 warnings, 0 errors)

swift test
→ Executed 741 tests, with 0 failures (0 unexpected)
```
