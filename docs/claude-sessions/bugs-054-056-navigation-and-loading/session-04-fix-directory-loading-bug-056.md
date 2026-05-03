---
session: 4
title: "Fix Directory Loading Spinner Delay (Bug #056)"
depends_on: [1]
touches:
  - LocalFileSystemProvider.swift
  - LocalDirectoryEnumerator.swift
parallel_safe: true
---

# Session 04: Fix Directory Loading Spinner Delay (Bug #056)

Paste this into a new Claude Code session:

```md
## Continuity
Continue from Session 01 artifacts: docs/claude-sessions/bugs-054-056-navigation-and-loading/session-01-handoff.md

## Mission
Eliminate the 3+ second spinner delay when opening a folder with only one file (e.g., Desktop with PRD-2026-02-24.md). Identify and fix actor scheduling delays, excessive FSEvents setup, or permission-check bottlenecks in LocalFileSystemProvider/LocalDirectoryEnumerator.

## Repository Anchors
- LocalFileSystemProvider.swift — async enumeration entry point
- LocalDirectoryEnumerator.swift — directory enumeration logic, FSEvents setup, permission checks

## Tasks

1. Read session-01-handoff.md to get the exact lines in LocalFileSystemProvider and LocalDirectoryEnumerator causing the delay.

2. Profile the delay: Check for:
   - Unnecessary FSEvents subscriptions that could be deferred or removed for small directories
   - Actor scheduling overhead that could be reduced by batching or streamlining
   - Permission prompts that trigger on first access—consider caching or deferring
   - Synchronous filesystem operations that should be async

3. Implement the fix:
   - If FSEvents is the bottleneck, consider lazy-loading or skipping for small directories
   - If actor scheduling is the issue, optimize the async/await pattern or reduce context switches
   - If permissions are the culprit, cache results or make prompts async

4. Manually test:
   - Open local:/ > Users > aramirez
   - Double-click Desktop folder
   - Verify the spinner appears for <500ms (or not at all) before the single file loads

## Deliverables
- Modified LocalFileSystemProvider.swift and/or LocalDirectoryEnumerator.swift with performance fix.
- `docs/claude-sessions/bugs-054-056-navigation-and-loading/session-04-handoff.md` documenting the fix, suspected root cause, changes made, and timing measurements.

## Quality Gates
- Build passes: `xcodebuild build`
- Manual testing: single-file folder loads with minimal or no spinner delay.

## Exit Criteria
- Directory with one file loads in <1 second (ideally <500ms) with no perceptible spinner.
- No new compiler warnings or test failures.
- Performance improvement measured and documented.
```
