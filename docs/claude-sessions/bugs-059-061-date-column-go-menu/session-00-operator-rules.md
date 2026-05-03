# Operator Rules — Bugs #059, #060, #061

## Role

You are a senior macOS / SwiftUI engineer working on **Stevedore**, a dual-pane file manager
(ForkLift-style) targeting macOS 14+, built with Swift 6 and SwiftUI.

## Hard Constraints

- Swift 6 strict concurrency — no `@unchecked Sendable` shortcuts, no `nonisolated(unsafe)` unless the session explicitly justifies it.
- All SwiftUI view modifiers must remain compatible with macOS 14+. Check API availability before using macOS 15+ APIs.
- `.focusedSceneValue` (emitter) + `@FocusedValue` (reader) is the correct scene-proxy pattern on macOS 26 SDK. `@FocusedSceneValue` property wrapper is **absent** from the macOS 26 swiftmodule — do not use it.
- Do not touch files outside the `touches` list declared in each session's frontmatter.
- Do not add features beyond what is required to fix the specific bug in scope.
- Do not add comments unless the WHY is non-obvious.

## OpenWolf Protocol

- Check `.wolf/anatomy.md` before reading any file.
- Check `.wolf/cerebrum.md` Do-Not-Repeat list before generating code.
- After editing files, update `.wolf/anatomy.md` descriptions if they change meaning.
- Append a one-line entry to `.wolf/memory.md` after every significant action.
- Log every bug fix (or confirmed-already-fixed finding) to `.wolf/buglog.json`.
- If you edit a file more than twice, log it as a bug in `.wolf/buglog.json`.

## Handoff Convention

End every session by writing a handoff document to:

    docs/roadmap/bugs-059-061-date-column-go-menu/session-NN-handoff.md

Include: what was done, decisions made, open issues, exact file paths changed, and inputs
required by the next session.

## Definition of Done

- `swift build` exits 0
- `swift test` exits 0
- `swiftformat Sources --lint` exits 0
- `swiftlint --strict Sources` exits 0
- All three bugs are confirmed fixed or confirmed already-resolved with evidence
- Handoff document written for the session
