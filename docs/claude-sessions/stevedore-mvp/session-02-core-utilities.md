---
session: 02
title: "Core Utilities"
depends_on: [01]
touches:
  - Sources/Core/Utilities/**
  - Tests/CoreTests/Utilities/**
parallel_safe: true
---

# Session 02: Core Utilities

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01 artifacts. Read `docs/roadmap/stevedore-mvp/session-01-handoff.md` and `docs/architecture.md`. The Core types and protocols already exist under `Sources/Core/Types` and `Sources/Core/Protocols`; do not modify them.

Mission
Provide the small, pure helpers every other module relies on — path manipulation, byte-size and date formatting, sort/filter combinators, and async sequence utilities — without any UI or I/O dependencies.

Repository anchors
- Sources/Core/Utilities/PathUtilities.swift
- Sources/Core/Utilities/ByteCountFormatter+Stevedore.swift
- Sources/Core/Utilities/DateFormatter+Stevedore.swift
- Sources/Core/Utilities/SortDescriptors.swift
- Sources/Core/Utilities/Filters.swift
- Sources/Core/Utilities/AsyncSequence+Helpers.swift
- Sources/Core/Utilities/Result+Helpers.swift
- Tests/CoreTests/Utilities/*.swift

Tasks
1. `PathUtilities`: extension/sibling functions on `FilePath` for `parent`, `appending`, `relative(to:)`, `commonAncestor(_:_:)`, scheme-aware joining for remote paths, and `displayName` honoring locale-sensitive collation.
2. Byte-size formatting with binary (KiB/MiB) and decimal (KB/MB) modes; locale-aware. Used by every UI listing.
3. Date formatting helpers: relative ("2 minutes ago") and absolute medium-style; respect user locale.
4. `SortDescriptors`: declarative comparators for `FileItem` (name, size, modified, kind, extension) honoring stable secondary order. Provide `.directoriesFirst` flag.
5. `Filters`: composable predicates by kind, glob, hidden state. Glob matching supports `*`, `?`, `**`.
6. AsyncSequence helpers: `chunked(by:)`, `throttled(for:)`, `withProgress(_:)` reporting via `Progress` callback.
7. Result helpers: `mapErrorTo`, `asyncFlatMap`, ergonomic conversion to `StevedoreError`.

Deliverables
- All files listed above with full XCTest coverage (≥90% line coverage on this module).
- `docs/roadmap/stevedore-mvp/session-02-handoff.md` listing utilities exported and any non-obvious invariants.

Quality gates
- `swift build --target Core`
- `swift test --filter CoreTests`
- `swiftformat --lint Sources/Core/Utilities Tests/CoreTests/Utilities`
- `swiftlint --strict --path Sources/Core/Utilities`

Exit criteria
- All utilities are pure (no global state, no I/O), `Sendable`, and unit-tested across edge cases (empty inputs, locale variation, very large byte counts, deep paths).
- No public surface added to `Sources/Core/Types` or `Sources/Core/Protocols`.
- Tests cover at minimum: glob match negative cases, sort stability, byte formatter rounding boundaries, common-ancestor across schemes.
```
