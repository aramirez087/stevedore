---
session: 3
title: "Fix Home Sidebar Path (Bug #055)"
depends_on: [1]
touches:
  - Sources/UI/Sidebar/SidebarViewModel.swift
parallel_safe: true
---

# Session 03: Fix Home Sidebar Path (Bug #055)

Paste this into a new Claude Code session:

```md
## Continuity
Continue from Session 01 artifacts: docs/claude-sessions/bugs-054-056-navigation-and-loading/session-01-handoff.md

## Mission
SCOPE-LOCKED TO BUG #055 ONLY: Fix the home sidebar button so it navigates to FileManager.default.homeDirectoryForCurrentUser instead of /System/Volumes/Data/home. Do NOT work on bugs #054 or #056.

## CRITICAL: Verify You Are Fixing Bug #055
Read session-01-handoff.md. It MUST contain root cause analysis for bug #055 with exact line numbers in SidebarViewModel.swift. If the handoff does not mention bug #055, STOP and ask the user to restart.

## Repository Anchors
- Sources/UI/Sidebar/SidebarViewModel.swift — home URL construction

## Tasks

1. Read session-01-handoff.md and extract the exact line numbers and code snippets for bug #055.

2. Find the code constructing the home sidebar item's URL in SidebarViewModel.swift.

3. Replace any path string construction (like `/Users/<username>` or `/home`) with `FileManager.default.homeDirectoryForCurrentUser`.

4. Manually test:
   - Click "home" in the sidebar Devices section
   - **Verify**: Path is local:/ > Users > <your-username> (NOT /System/Volumes/Data/home)

## Deliverables
- Modified SidebarViewModel.swift with bug #055 fix
- `docs/claude-sessions/bugs-054-056-navigation-and-loading/session-03-handoff.md` with exact lines changed and manual test results

## Quality Gates
- Build passes: `xcodebuild build`
- Manual testing: home sidebar navigates to correct directory

## Exit Criteria
- Bug #055 is fixed (home sidebar navigates to FileManager.default.homeDirectoryForCurrentUser)
- No new compiler warnings or test failures
```
