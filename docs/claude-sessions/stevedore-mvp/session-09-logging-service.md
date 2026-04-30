---
session: 09
title: "Logging Service"
depends_on: [01]
touches:
  - Sources/Services/Logging/**
  - Tests/ServicesTests/LoggingTests/**
parallel_safe: true
---

# Session 09: Logging Service

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01 artifacts. Read `docs/roadmap/stevedore-mvp/session-01-handoff.md`. The `AppLogger` protocol is defined in `Sources/Core/Protocols`.

Mission
Provide a thin, performant `os.Logger`-backed implementation of `AppLogger` plus a structured event type so the rest of the app can log consistently. Include an in-memory ring buffer for the future Diagnostics panel.

Repository anchors
- Sources/Services/Logging/OSLogger.swift
- Sources/Services/Logging/LogEvent.swift
- Sources/Services/Logging/LogCategory.swift
- Sources/Services/Logging/LogRingBuffer.swift (bounded actor; for diagnostics export)
- Sources/Services/Logging/Redaction.swift (redact tokens, paths, credentials)
- Sources/Services/Logging/SignpostHelper.swift (os_signpost wrappers for performance regions)
- Tests/ServicesTests/LoggingTests/*.swift

Tasks
1. `LogCategory` enum — one case per subsystem (`fileSystem`, `remote`, `archive`, `ui`, `operations`, `sync`, `credentials`, `settings`). Maps to `os.Logger(subsystem: bundleID, category:)`.
2. `OSLogger` conforms to `AppLogger` from Core. Levels: debug, info, notice, warning, error, fault. Supports interpolation with privacy hints.
3. `LogEvent` struct: timestamp, category, level, message, optional metadata `[String: String]`. Used for ring buffer + future export.
4. `LogRingBuffer` actor: bounded capacity (default 2,000), thread-safe push/snapshot. `OSLogger` writes through to both `os.Logger` and the ring buffer.
5. `Redaction` utility: detects substrings shaped like passwords, AWS keys, JWTs, full POSIX paths under `/Users/...` (replace user portion with `~`). Ship a small set of regex rules; tests cover false-positive cases.
6. `SignpostHelper`: `withSignpost(_:_:)` async wrapper around `os_signpost(.begin)`/`.end` for tracing slow operations (large copies, FTP listings).
7. Tests: redaction round-trips, ring buffer eviction, level filtering, signpost wrapping reraises original errors.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-09-handoff.md` covering subsystem/category convention, redaction rules, and how the Diagnostics panel will later read the ring buffer.

Quality gates
- `swift build --target ServicesLogging`
- `swift test --filter LoggingTests`
- `swiftformat --lint Sources/Services/Logging Tests/ServicesTests/LoggingTests`
- `swiftlint --strict --path Sources/Services/Logging`

Exit criteria
- Every log call sites in downstream sessions resolves to one of the declared categories — no untyped strings.
- Redaction tests cover at least: AWS access key, SSH passphrase, full POSIX user paths, bearer tokens.
- Ring buffer respects bounds under burst writes (10k logs in <1s).
```
