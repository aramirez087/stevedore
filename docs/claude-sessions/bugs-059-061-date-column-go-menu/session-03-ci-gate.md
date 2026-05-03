---
session: 3
title: "CI Gate — Verify all fixes"
depends_on: [2]
touches: []
parallel_safe: false
model: "sonnet"
---

# Session 03: CI Gate — Verify All Fixes

Paste this into a new Claude Code session:

```md
Read docs/claude-sessions/bugs-059-061-date-column-go-menu/session-00-operator-rules.md first.

## Continuity

Continue from Session 02 artifacts.
Read docs/roadmap/bugs-059-061-date-column-go-menu/session-02-handoff.md to confirm which
files were changed and what each fix does.

## Mission

Run the full quality gate suite, verify every fix is present and correct, and produce a
go/no-go report.

## Repository Anchors

- Sources/UI/MainWindow/PaneHost.swift — confirm #059 and #060 fixes are present
- Sources/UI/Menus/Sections/GoMenu.swift — confirm #061 verdict matches handoff
- docs/roadmap/bugs-059-061-date-column-go-menu/session-02-handoff.md — fix inventory

## Tasks

1. Read the session-02 handoff. Verify each fix is present in the corresponding file at
   the reported line numbers.
2. Bug #059 check: grep FileBrowserView for the date `.frame(width:)` — confirm width
   is ≥ 130 and `.lineLimit(1)` is present on the same Text view.
3. Bug #060 check: confirm the fix for right-pane dates is present and logically correct.
4. Bug #061 check: confirm the emitter uses `.focusedSceneValue` (already the case or
   explicitly fixed in session 02).
5. Run full quality gate suite. Iterate until all pass:

    swift build
    swift test
    swiftformat Sources --lint
    swiftlint --strict Sources

6. Write the go/no-go report as the handoff.

## Deliverables

- docs/roadmap/bugs-059-061-date-column-go-menu/session-03-handoff.md

## Quality Gates

    swift build
    swift test
    swiftformat Sources --lint
    swiftlint --strict Sources

All four must exit 0 before go verdict is issued.

## Exit Criteria

- All four quality-gate commands exit 0.
- Each bug (#059, #060, #061) has a confirmed fix or confirmed-already-fixed entry.
- Handoff contains a clear GO / NO-GO verdict with evidence.
```
