---
session: 13
title: "Preview Service (Quick Look)"
depends_on: [01, 02, 03]
touches:
  - Sources/Features/Preview/**
  - Tests/FeaturesTests/PreviewTests/**
parallel_safe: true
---

# Session 13: Preview Service (Quick Look)

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 03 artifacts. Read each handoff.

Mission
Generate file previews for the right-hand preview panel and for inline thumbnails — wrapping `QuickLookThumbnailing` and `QLPreviewPanel` plus first-party renderers for text/markdown/code so common file types show without launching helpers.

Repository anchors
- Sources/Features/Preview/PreviewService.swift
- Sources/Features/Preview/ThumbnailGenerator.swift (QuickLookThumbnailing)
- Sources/Features/Preview/QuickLookPanelController.swift (QLPreviewPanel bridge)
- Sources/Features/Preview/Renderers/TextPreviewRenderer.swift
- Sources/Features/Preview/Renderers/ImagePreviewRenderer.swift
- Sources/Features/Preview/Renderers/CodePreviewRenderer.swift (syntax via TextKit2 + token map)
- Sources/Features/Preview/PreviewCache.swift (NSCache-backed, bounded by total bytes)
- Tests/FeaturesTests/PreviewTests/*.swift

Tasks
1. `PreviewService` decides the appropriate renderer for a `FileItem` by extension + magic bytes; falls back to QuickLook thumbnail.
2. `ThumbnailGenerator` wraps `QLThumbnailGenerator` returning `NSImage` at requested sizes; coalesces concurrent requests for the same key.
3. `QuickLookPanelController` integrates `QLPreviewPanel` for the spacebar-preview behavior. AppKit interop done here so SwiftUI views stay clean.
4. `TextPreviewRenderer` reads the first ~1MB of a file, detects encoding, and returns an attributed string sized for the panel.
5. `CodePreviewRenderer` provides minimal language-aware coloring for the top ~20 languages via a hand-rolled token map (no external deps); falls back to plain text.
6. `ImagePreviewRenderer` decodes via `NSImage` honoring orientation; resamples to fit the panel.
7. `PreviewCache` is an `NSCache<NSString, CachedPreview>` with a total-byte limit; eviction tested.
8. Tests: renderer dispatch by file kind, cache eviction at limit, cancellation of in-flight thumbnail when consumer task cancels, encoding detection for UTF-8/UTF-16/Latin-1.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-13-handoff.md` describing renderer dispatch order, cache policy, and Quick Look integration points.

Quality gates
- `swift build --target FeaturesPreview`
- `swift test --filter PreviewTests`
- `swiftformat --lint Sources/Features/Preview Tests/FeaturesTests/PreviewTests`
- `swiftlint --strict --path Sources/Features/Preview`

Exit criteria
- Preview generation never blocks the main actor — verified by tests that assert calls are awaited off the main actor.
- Cache stays under its byte cap under burst loads of 1,000 distinct previews.
- Quick Look panel opens and closes cleanly when toggled twice in succession.
```
