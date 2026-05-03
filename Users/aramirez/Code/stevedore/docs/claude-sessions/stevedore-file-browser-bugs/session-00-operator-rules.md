# Operator Rules — Stevedore File Browser Bug Fixes

## Persona
You are the engineer fixing two UX bugs in Stevedore's `FileBrowserView`. Each session is a fresh Claude Code process with **no memory** of prior sessions; recover state by reading prior handoffs in `docs/roadmap/stevedore-file-browser-bugs/` and the source tree. Trust files, not memory.

## Hard Constraints

### Safety
- Never commit secrets, real credentials, or fixtures with PII.
- Never run destructive `git` commands (force-push, hard reset, branch deletion) without explicit instruction.
- Never bypass hooks (`--no-verify`) or signing checks.

### Stack & Architecture
- Swift 6 with strict concurrency enabled on every target.
- macOS 14.0+ deployment target.
- SwiftUI is the primary UI layer. AppKit interop only when SwiftUI cannot express the behavior.
- Build system: `Stevedore.xcodeproj` (xcodegen-generated). `Package.swift` governs library/test targets.
- All public types `Sendable`. `final` classes by default. No `@unchecked Sendable` without justifying comment.
- No force-unwraps. No `try!` outside XCTest. No `print()` — use `os.Logger`.

### Coding Standards
- 4-space indent, 120-col soft limit. SwiftLint + SwiftFormat configs at repo root are authoritative.
- Touch only the file globs in your session frontmatter `touches:` list.
- Tests live under `Tests/<Module>Tests/`. Use `XCTest`.
- If you spot a defect outside your `touches:` scope, record it in the handoff under "Open issues" — do not fix it.

## Handoff Convention
End every session by writing `docs/roadmap/stevedore-file-browser-bugs/session-NN-handoff.md`:

```
# Session NN Handoff — <title>

## Scope
One-paragraph summary.

## What changed
Bullet list of files added/modified.

## Decisions
Key technical choices and rationale.

## Open issues / risks
Anything left undone or suspected defects.

## Next-session inputs
What the next session must read before starting.

## Verification
Exact commands run and outcomes (pass/fail counts).
```

## Definition of Done (per session)
- All quality gates listed in the session prompt pass cleanly.
- New behavior is covered by tests where the type is testable.
- Decisions recorded in the handoff doc.
- Diff scoped to declared `touches:` globs.
- No dead code, no commented-out blocks, no scratch files.
- `swift build` for affected targets succeeds with zero warnings under `-warnings-as-errors`.
