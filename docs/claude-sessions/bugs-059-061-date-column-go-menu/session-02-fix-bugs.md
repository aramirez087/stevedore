---
session: 2
title: "Fix bugs #059, #060, #061"
depends_on: [1]
touches:
  - Sources/UI/MainWindow/PaneHost.swift
  - Sources/UI/Menus/Sections/GoMenu.swift
  - docs/roadmap/bugs-059-061-date-column-go-menu/session-02-handoff.md
parallel_safe: false
model: "sonnet"
---

# Session 02: Fix Bugs #059, #060, #061

Paste this into a new Claude Code session:

```md
Read docs/claude-sessions/bugs-059-061-date-column-go-menu/session-00-operator-rules.md first.

## Continuity

Continue from Session 01 artifacts.
Read docs/roadmap/bugs-059-061-date-column-go-menu/session-01-handoff.md for exact line
numbers and proposed diffs before touching any file.

## Mission

Apply all fixes identified in the session-01 handoff for bugs #059 and #060.
For bug #061, apply the fix only if the session-01 verdict says it is not yet fixed.

## Repository Anchors

- Sources/UI/MainWindow/PaneHost.swift — FileBrowserView date column (bug #059, #060)
- Sources/UI/Menus/Sections/GoMenu.swift — Go menu proxy consumer (bug #061 if needed)
- Sources/UI/Menus/PaneCommandProxy.swift — proxy FocusedValues key (bug #061 if needed)

## Tasks

1. Read the session-01 handoff. Apply every fix it prescribes.
2. Bug #059 — Increase the date column frame width to accommodate the longest date string
   and add `.lineLimit(1)` to prevent wrapping. Use a fixed width wide enough for
   "December 31, 2025" in the system font at the caption size. Target ~130 pt.
3. Bug #060 — Apply the root-cause fix identified in the session-01 handoff. If the root
   cause is a nil `modificationDate` due to provider differences, fix the provider
   initialization or attribute fetching. If it is a task-scheduling race, fix the
   task ordering.
4. Bug #061 — If the session-01 verdict says "already fixed", skip and document that.
   If "not yet fixed", change `.focusedValue` to `.focusedSceneValue` on the proxy
   emitter in PaneHost.swift (reader stays as `@FocusedValue`).
5. Run `swift build`. Fix any compiler errors before proceeding.
6. Run `swift test`. Fix any test failures.
7. Run `swiftformat Sources --lint`. Fix any formatting violations.
8. Run `swiftlint --strict Sources`. Fix any lint violations.

## Deliverables

- Modified Sources/UI/MainWindow/PaneHost.swift
- Modified Sources/UI/Menus/Sections/GoMenu.swift (only if bug #061 fix required)
- docs/roadmap/bugs-059-061-date-column-go-menu/session-02-handoff.md

## Quality Gates

    swift build
    swift test
    swiftformat Sources --lint
    swiftlint --strict Sources

All four must exit 0.

## Exit Criteria

- Bug #059 fix applied: date frame width ≥ 130 and `.lineLimit(1)` present.
- Bug #060 fix applied: right pane dates appear (or root cause fix merged).
- Bug #061: either fix applied or "already fixed" documented.
- All quality gates pass.
- Handoff written listing every changed file and line.
```
