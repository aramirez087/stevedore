---
session: 1
title: "Charter — Audit bugs #059, #060, #061"
depends_on: []
touches:
  - docs/roadmap/bugs-059-061-date-column-go-menu/session-01-handoff.md
parallel_safe: false
model: "opus"
---

# Session 01: Charter — Audit Bugs #059, #060, #061

Paste this into a new Claude Code session:

```md
Read docs/claude-sessions/bugs-059-061-date-column-go-menu/session-00-operator-rules.md first.

## Mission

Audit the three bugs from docs/bug-report-2026-05-03.md and produce a precise diagnosis
and fix plan for each one.

## Repository Anchors

- docs/bug-report-2026-05-03.md — bug descriptions and root-cause hints
- Sources/UI/MainWindow/PaneHost.swift — FileBrowserView (date column rendering, lines 204-236)
- Sources/UI/MainWindow/PaneSession.swift — per-pane view model and provider
- Sources/UI/MainWindow/MainWindowView.swift — dual-pane wiring
- App/Stevedore/AppEnvironment.swift — leftSession / rightSession construction
- Sources/UI/Menus/Sections/GoMenu.swift — Go menu proxy consumer
- Sources/UI/Menus/PaneCommandProxy.swift — proxy type and FocusedValues key

## Tasks

1. Read every file listed under Repository Anchors.
2. Bug #059 — Date column wraps: Locate the `Text(date, style: .date)` in `FileBrowserView`.
   Measure the current frame width. Determine the minimum width required to fit the longest
   possible locale-default date string ("December 31, 2025" — 17 chars) without wrapping.
   Note whether `.lineLimit(1)` is applied.
3. Bug #060 — Right pane no dates: Trace why `item.attributes.modificationDate` might be
   nil for right-pane items but not left-pane items. Compare how `leftSession` and
   `rightSession` are constructed. Read `PaneSession.swift` to check if the provider or
   enumeration differs per-pane. Inspect `.task(id: session.currentPath)` — could a race
   or double-trigger cause right-pane items to be loaded with stale/nil attributes?
4. Bug #061 — Go menu non-functional: Read PaneHost.swift line 50. Confirm whether
   `.focusedSceneValue` or `.focusedValue` is currently used. Read GoMenu.swift line 5.
   Confirm whether `@FocusedValue` or `@FocusedSceneValue` is used for the reader.
   State definitively: is this bug already fixed, or is a change still required?
5. Write the handoff with: exact line numbers to change for each bug, proposed diffs,
   and a "fix or skip" verdict for bug #061.

## Deliverables

- docs/roadmap/bugs-059-061-date-column-go-menu/session-01-handoff.md

## Quality Gates

No code changes this session. Handoff must include exact file paths and line numbers.

## Exit Criteria

- Handoff exists and contains a concrete fix plan (line numbers + proposed change) for
  bugs #059 and #060, and a confirmed verdict on bug #061.
```
