---
session: 1
title: "Charter: Audit Architecture and Identify Root Causes"
depends_on: []
touches: []
parallel_safe: false
model: "opus"
---

# Session 01: Charter — Audit Architecture and Identify Root Causes

Paste this into a new Claude Code session:

```md
## Mission
Audit the Stevedore file browser codebase to understand PaneSession/PaneCommandProxy/SidebarViewModel/LocalFileSystemProvider architecture, trace the root causes of bugs #054 (back navigation broken), #055 (home sidebar wrong path), and #056 (directory loading spinner), and document findings for three parallel fix sessions.

## Repository Anchors
- PaneSession.swift — navigation history and navigate(to:) implementation
- PaneCommandProxy.swift — command routing (back, forward, menu actions)
- SidebarViewModel.swift — home button URL construction
- LocalFileSystemProvider.swift — async file enumeration
- LocalDirectoryEnumerator.swift — spinner and enumeration delays
- View files using sidebar and pane components

## Tasks

1. **Understand back navigation flow**: Trace how toolbar back button, Go menu Back, and ⌘[ keyboard shortcut route through PaneCommandProxy to PaneSession. Identify where history stack is managed and whether navigate(to:) pushes to the stack.

2. **Trace home sidebar resolution**: Find where SidebarViewModel constructs the home URL. Check if it uses FileManager.default.homeDirectoryForCurrentUser or if it builds a path string like `/Users/<username>`.

3. **Profile directory enumeration**: Identify why a single-file folder shows a spinner for 3+ seconds. Check LocalFileSystemProvider/LocalDirectoryEnumerator for actor scheduling delays, FSEvents subscription overhead, or permission prompts.

4. **Document architecture**: Write a clear summary of how these three components interact. Identify the exact lines in each file where the bugs originate.

5. **Create handoff for parallel work**: Document all findings with file paths, line numbers, and suspected fixes so sessions 02–04 can work in parallel without re-auditing.

## Deliverables
- `docs/claude-sessions/bugs-054-056-navigation-and-loading/session-01-handoff.md` with root-cause analysis, file paths, line numbers, and specific code snippets showing the bugs.

## Quality Gates
- Compile the project cleanly: `xcodebuild build` (no errors).
- Confirm the three bugs manually:
  - Bug #054: Navigate to Desktop, try back button—verify it doesn't work.
  - Bug #055: Click home in sidebar—verify path is `/System/Volumes/Data/home` (wrong).
  - Bug #056: Open Desktop folder—time the spinner, confirm it appears for 3+ seconds.

## Exit Criteria
- All three bugs reproduced and root causes documented with file/line references.
- Clear handoff ready for parallel fix sessions.
```
