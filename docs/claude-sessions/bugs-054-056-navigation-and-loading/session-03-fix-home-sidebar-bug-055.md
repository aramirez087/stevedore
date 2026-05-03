---
session: 3
title: "Fix Home Sidebar Path (Bug #055)"
depends_on: [1]
touches:
  - SidebarViewModel.swift
parallel_safe: true
---

# Session 03: Fix Home Sidebar Path (Bug #055)

Paste this into a new Claude Code session:

```md
## Continuity
Continue from Session 01 artifacts: docs/claude-sessions/bugs-054-056-navigation-and-loading/session-01-handoff.md

## Mission
Fix the home sidebar button so it navigates to the user's actual home directory (FileManager.default.homeDirectoryForCurrentUser) instead of the system firmlink path /System/Volumes/Data/home.

## Repository Anchors
- SidebarViewModel.swift — home URL construction and sidebar item definition

## Tasks

1. Read session-01-handoff.md to get the exact line number in SidebarViewModel.swift where the home URL is constructed.

2. Find the code that creates the home sidebar item's URL. If it's building a path string or resolving from a firmlink, replace it with FileManager.default.homeDirectoryForCurrentUser.

3. Ensure the home button's navigation target is now the correct user home directory (e.g., local:/ > Users > aramirez).

4. Manually test:
   - Click the "home" item in the Devices section of the sidebar
   - Verify you navigate to local:/ > Users > <your-username> (not /System/Volumes/Data/home)

## Deliverables
- Modified SidebarViewModel.swift with correct home URL resolution.
- `docs/claude-sessions/bugs-054-056-navigation-and-loading/session-03-handoff.md` documenting the fix, lines changed, and manual test results.

## Quality Gates
- Build passes: `xcodebuild build`
- Manual testing: home sidebar item navigates to the correct directory.

## Exit Criteria
- Home sidebar item now navigates to FileManager.default.homeDirectoryForCurrentUser.
- Path shown is local:/ > Users > <username>, not the system firmlink.
- No new compiler warnings or test failures.
```
