# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-05-01

## User Preferences

<!-- How the user likes things done. Code style, tools, patterns, communication. -->

## Key Learnings

- **Project:** Stevedore
- **SwiftFormat `--lint` argument order (0.59 bug):** Pass paths BEFORE `--lint` flag: `swiftformat <paths> --lint`, not `swiftformat --lint <paths>`.
- **`ByteCountFormatter` has no `locale` property on macOS:** The property does not exist in the public API. Store locale in wrapper but don't apply it; test against a reference formatter with same countStyle.
- **`TimeZone.gmt` vs `TimeZone(secondsFromGMT:)`:** On macOS 26 SDK, `TimeZone(secondsFromGMT:)` returns `TimeZone?` (optional). Use `TimeZone.gmt` (macOS 13+, non-optional) in tests to stay warning-clean.
- **`AsyncSequence<Element, Failure>` constrained existential is macOS 15+ only:** Always return `AsyncThrowingStream<Output, any Error>` for async sequence operators targeting macOS 14.
- **`FilePath.relative(to:)` nil vs empty distinction:** Returns `[]` when `self == base` (same path); returns `nil` when base is not a prefix or schemes differ.
- **`withProgress` bytesDone carries item counts when byte sizes unavailable:** When `Element` is not `FileItem` or `sizeInBytes` is nil, `bytesDone` in `Progress` carries the item count, not bytes.
- **`GlobMatcher` ergonomic prefix:** Patterns without `/` are automatically prefixed with `**/`. Patterns with `/` are used as-is.
- **`StevedoreErrorBridge` lives in `Result+Helpers.swift`:** To stay within the session touch-glob without touching `Sources/Core/Errors/`.
- **SwiftLint trailing_comma config:** `.swiftlint.yml` has `trailing_comma: mandatory_comma: true` to reconcile with SwiftFormat `--commas always`.

## Do-Not-Repeat

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->
