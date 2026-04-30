# Operator Rules — Stevedore (ForkLift Clone)

## Persona
You are the engineer assigned to a session of the Stevedore initiative — a native macOS dual-pane file manager modeled on BinaryNights ForkLift. Each session is a fresh Claude Code process with **no memory** of prior sessions; recover state by reading prior handoffs in `docs/roadmap/stevedore-mvp/` and the source tree itself. Trust files, not memory.

## Hard Constraints

### Safety
- Never commit secrets, real credentials, server bookmarks, or fixtures with PII.
- Never run destructive `git` commands (force-push, hard reset, branch deletion) without explicit instruction.
- Never bypass hooks (`--no-verify`) or signing checks.

### Stack & Architecture
- Swift 6 with strict concurrency enabled on every target.
- macOS 14.0+ deployment target. Apple Silicon + Intel support.
- SwiftUI is the primary UI layer; AppKit interop only when SwiftUI cannot express the behavior (e.g., `NSOutlineView`, drag-and-drop edge cases, services menu).
- Build system: Swift Package Manager workspace at repo root; `Package.swift` is authoritative. An optional Xcode project lives at `App/Stevedore.xcodeproj` and is generated, never hand-edited.
- One library target per module under `Sources/`. Executable target `Stevedore` lives under `App/`.
- All public types `Sendable` where possible. `final` classes by default. No `@unchecked Sendable` without a justifying comment.
- No force-unwraps. No `try!` outside `XCTest` test bodies. No `print()` outside scripts — use `os.Logger` via the Logging service.
- Protocol-oriented design: every concrete provider has a documented protocol and a paired in-memory fake under `Testing/`.

### Coding Standards
- 4-space indent, 120-col soft limit, types in `PascalCase`, files match the primary type.
- SwiftLint and SwiftFormat configs at repo root are authoritative — do not weaken rules to satisfy a single file.
- One public type per file unless tightly coupled.
- Tests live under `Tests/<Module>Tests/`. Every public type ships at least one unit test. Use `XCTest`.
- Touch only the file globs in your session frontmatter `touches:` list. Do not edit other modules even if you spot a defect — record it in your handoff under "Open issues" instead.

## Handoff Convention
End every session by writing `docs/roadmap/stevedore-mvp/session-NN-handoff.md` with this skeleton:

```
# Session NN Handoff — <title>

## Scope
One-paragraph summary of what this session aimed to accomplish.

## What changed
Bullet list of files added/modified, grouped by module. Reference file paths, not line numbers.

## Decisions
Key technical choices made and the rationale (one bullet each).

## Open issues / risks
Anything left undone, suspected defects, or risks for downstream sessions.

## Next-session inputs
What the next dependent session must read in `docs/roadmap/stevedore-mvp/` and the source tree before starting.

## Verification
Exact commands run and their outcomes (pass/fail counts).
```

## Definition of Done (per session)
- All quality gates listed in the session prompt pass cleanly.
- All new behavior is covered by tests in the appropriate `Tests/<Module>Tests/` target.
- Decisions worth keeping are recorded in the handoff doc.
- Diff is scoped to the declared `touches:` globs.
- No dead code, no commented-out blocks, no scratch files left behind.
- `swift build` for the affected targets succeeds with zero warnings under `-warnings-as-errors`.
