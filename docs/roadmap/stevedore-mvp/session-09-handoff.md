# Session 09 Handoff — Logging Service

## Scope

Implement the `ServicesLogging` module: a production `os.Logger`-backed `AppLogger`, a structured `LogEvent` value type, a bounded actor ring buffer for the future Diagnostics panel, a `Redaction` utility that scrubs five sensitive-data patterns, and an `OSSignposter`-based async signpost wrapper for performance tracing.

## What changed

### `Sources/Services/Logging/`
- **Deleted**: `Placeholder.swift` — replaced by the files below; the `ServicesLoggingModule` sentinel is re-declared in `OSLogger.swift` to keep `ServicesLoggingSmokeTests` compiling without touching an out-of-scope file.
- **`LogEvent.swift`** — `public struct LogEvent: Sendable, Hashable, Codable` with `id: UUID`, `timestamp: Date`, `category: LogCategory`, `level: LogLevel`, `message: String`, `metadata: [String: String]`. Codable synthesis is automatic; all fields are natively codable.
- **`LogCategory.swift`** — Module-internal `extension LogCategory` that adds `var osLogger: Logger`, mapping each category's `rawValue` to an `os.Logger(subsystem:category:)` instance. Not `public`; only `ServicesLogging` call sites can reach it.
- **`LogRingBuffer.swift`** — `public actor LogRingBuffer` with `defaultCapacity = 2000`. O(1) push via rolling write cursor; O(n) `snapshot` that linearises into chronological order. Also exposes `snapshot(minLevel:)` for filtered reads.
- **`Redaction.swift`** — `public enum Redaction` with five `nonisolated(unsafe) static let` regex constants and a `static func redact(_:) -> String`. See Decisions for why `nonisolated(unsafe)` is used.
- **`SignpostHelper.swift`** — `public enum SignpostHelper` with `static func withSignpost<T: Sendable>(_:_:) async rethrows -> T`. Wraps any async throwing work in an `OSSignposter` interval. `@discardableResult` for `Void`-result callers.
- **`OSLogger.swift`** — `public final class OSLogger: AppLogger, Sendable`. Calls `Redaction.redact` then writes to `os.Logger` using the appropriate level method, then `await`s `ringBuffer.push`. Exposes `var events: [LogEvent] { get async }` for the Diagnostics panel. Hosts the `ServicesLoggingModule` sentinel at the bottom under `// MARK: - Module marker`.

### `Tests/ServicesTests/LoggingTests/`
- **`LogEventTests.swift`** — Codable round-trip, Hashable identity, default field generation.
- **`LogRingBufferTests.swift`** — Push within capacity, eviction with chronological ordering, burst write (10 k pushes < 1 s), level filter.
- **`RedactionTests.swift`** — Positive cases: AWS key, JWT, bearer token, POSIX user path, SSH passphrase, `password=` and `secret:` patterns. Negative (false-positive) cases: short AKIA string, `/System/Library` path, plain text, short bearer token.
- **`OSLoggerTests.swift`** — Ring buffer write, pre-write redaction, metadata storage, `events` property delegation, protocol conformance, multiple log levels.
- **`SignpostHelperTests.swift`** — Non-throwing value return, throwing error preservation, void closure completion, string return.

## Decisions

- **`LogCategory` extended, not re-declared.** `Core.LogCategory` already carries all required cases. Adding an `extension LogCategory { var osLogger: Logger }` in `ServicesLogging` avoids a shadow type that would break the `AppLogger` protocol contract.
- **`nonisolated(unsafe) static let` for regex constants.** Swift 6 strict concurrency requires `static let` properties of `Sendable` types. `Regex<Output>` is an immutable value type but Apple's SDK does not yet mark it `Sendable`. `nonisolated(unsafe)` is the correct suppression for a provably safe global constant; `@unchecked Sendable` on the enum would not address the property-level error. Each property carries a justification comment.
- **`Self` in `LogRingBuffer.init` default removed.** Swift rejects covariant `Self` in default argument expressions. The initialiser default is the literal `2000` (matching `defaultCapacity`) instead of `Self.defaultCapacity`.
- **`ServicesLoggingModule` sentinel kept in `OSLogger.swift`.** Deleting `Placeholder.swift` would break the smoke test at `Tests/ServicesTests/Logging/ServicesLoggingSmokeTests.swift`, which is outside this session's `touches:` scope. Re-declaring the three-line enum in `OSLogger.swift` under a `MARK` is an explicit exception to the one-public-type-per-file convention, documented here.
- **`swift-log` (`Logging` product) is a declared dependency but unused at runtime.** The dependency is in `Package.swift` (frozen) and may be used by a future structured-logging backend session. All runtime logging goes through `os.Logger` directly.
- **`OSSignposter` signpost interval state used across `await` without `@unchecked Sendable`.** `OSSignpostIntervalState` is a value-type struct in the macOS 14 SDK; Swift 6 region isolation allows local value-type state to cross `await` points without crossing actor boundaries. No extension was needed in practice.
- **`privacy: .auto` for all `os.Logger` writes.** Messages are already scrubbed by `Redaction.redact` before reaching `os.Logger`, so `.auto` (developer-visible on development devices) is appropriate. Callers who need unconditional visibility should construct log messages containing no sensitive data.

## Subsystem / category convention

Every `os.Logger` instance is created as:
```swift
Logger(subsystem: OSLogger.subsystem, category: logCategory.rawValue)
```

`OSLogger.subsystem` resolves to `Bundle.main.bundleIdentifier ?? "com.stevedore.app"`. Category strings are the `rawValue` of `Core.LogCategory` (e.g. `"fileSystem"`, `"remote"`, `"credentials"`). Console.app's "subsystem" filter accepts `com.stevedore.app` to isolate Stevedore logs from all other processes.

**Downstream sessions must pass the correct `LogCategory` — no untyped strings are accepted at any call site.**

## Redaction rules

| Rule | Pattern | Replacement |
|------|---------|-------------|
| AWS Access Key ID | `AKIA[0-9A-Z]{16}` | `[REDACTED-AWS-KEY]` |
| JWT | `eyJ…base64url….eyJ….signature` | `[REDACTED-JWT]` |
| Bearer token | `(?i)bearer\s+[A-Za-z0-9_.\-]{20,}` | `[REDACTED-BEARER]` |
| POSIX user path | `/Users/[^/\s]+/` | `~/` |
| Password/passphrase | `(?i)(password\|passphrase\|passwd\|secret)\s*[:=]\s*\S+` | `<keyword>: [REDACTED]` |

Notes:
- Paths are matched at the POSIX level (not URL-level). Only `/Users/<username>/` is redacted; `/System/`, `/usr/`, and other prefixes are untouched.
- The AWS key pattern requires exactly 16 uppercase-alphanumeric characters after `AKIA`, preventing false positives on short strings like `AKIA1234`.
- Bearer tokens shorter than 20 characters are not redacted.

## Ring buffer access for the Diagnostics panel

The future Diagnostics panel should cast `any AppLogger` to `OSLogger` and read:
```swift
if let osLogger = logger as? OSLogger {
    let events = await osLogger.events   // [LogEvent], chronological, last 2 000
}
```

The ring buffer holds the last `LogRingBuffer.defaultCapacity` (2 000) events; older entries are silently evicted. `snapshot` is O(n) and should only be called when the panel is opened or when exporting diagnostics — not in the hot logging path.

For filtered reads (e.g. errors only):
```swift
let errors = await osLogger.ringBuffer.snapshot(minLevel: .error)
```
(Requires access to the `LogRingBuffer` actor directly; `OSLogger.ringBuffer` is `private`, so this requires a new accessor or protocol widening in a future session.)

## SignpostHelper usage

```swift
let items = try await SignpostHelper.withSignpost("FTP listing") {
    try await ftpClient.list(path: remotePath)
}
```

The `name` argument must be a `StaticString` literal. Instruments' "os_signpost" instrument and Time Profiler display intervals labeled by this name. Errors from the work closure are reraised without wrapping — the interval is always closed.

## Open issues / risks

1. **`LogRingBuffer.ringBuffer` is `private` in `OSLogger`**, so the Diagnostics panel cannot call `ringBuffer.snapshot(minLevel:)` without either widening `OSLogger` or changing the access level. The `events` property returns the unfiltered snapshot; a future session should add `func events(minLevel:) async -> [LogEvent]` to `OSLogger`.
2. **`Regex<Output>` not `Sendable` in Apple SDK.** Tracked by Swift Forums and expected to be resolved in a future Swift/SDK release. When fixed, the `nonisolated(unsafe)` annotations in `Redaction.swift` can be removed and replaced with plain `private static let`.
3. **`swift-log` dependency is unused at runtime.** If a future session never uses it, `Package.swift` should be updated to remove the dependency (requires unfreezing `Package.swift` per the epic roadmap).

## Next-session inputs

- `Sources/Services/Logging/OSLogger.swift` — concrete `AppLogger` with `events: [LogEvent] { get async }`.
- `Sources/Services/Logging/LogRingBuffer.swift` — actor; capacity 2 000; access via `OSLogger.events` or direct if access level is widened.
- `Sources/Services/Logging/Redaction.swift` — five redaction rules; call `Redaction.redact(_:)` before including user-controlled strings in log messages outside of `OSLogger`.
- `Sources/Core/Types/LogLevel.swift` — `LogLevel` and `LogCategory` definitions. All log call sites must use a declared `LogCategory` case.
- `Sources/Core/Protocols/AppLogger.swift` — protocol consumed by all feature/UI modules.
- `Sources/Core/Testing/RecordingLogger.swift` — in-memory fake for unit tests; does not redact or push to a ring buffer.

## Verification

All commands run from the worktree root.

- `swift build --target ServicesLogging -Xswiftc -warnings-as-errors` — **Build of target: 'ServicesLogging' complete!** (0 warnings, 0 errors)
- `swift test --filter ServicesTests` — **Executed 35 tests, with 0 failures** (includes ServicesLoggingSmokeTests, LogEventTests, LogRingBufferTests, RedactionTests, OSLoggerTests, SignpostHelperTests, plus credentials/settings smoke tests)
- `swift test` (full suite) — **Executed 78 tests, with 0 failures**
- `swiftformat Sources/Services/Logging Tests/ServicesTests/LoggingTests --lint` — **0/11 files require formatting**
- `swiftlint lint --strict Sources/Services/Logging` — **Found 0 violations, 0 serious in 98 files**
- `swiftlint lint --strict Tests/ServicesTests/LoggingTests` — **Found 0 violations, 0 serious in 98 files**
