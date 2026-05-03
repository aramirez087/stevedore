---
session: 3
title: "CI Gate: full build, tests, lint, format"
depends_on: [2]
touches:
  - docs/roadmap/stevedore-file-browser-bugs/session-03-handoff.md
parallel_safe: false
model: "opus"
---

# Session 03: CI Gate

Paste this into a new Claude Code session:

```md
## Continuity
Continue from Session 02 artifacts.
Read `docs/roadmap/stevedore-file-browser-bugs/session-02-handoff.md` before running any gate.

## Mission
Verify the entire codebase builds, passes all tests, and is clean under format and lint — then produce a go/no-go report.

## Repository anchors
- `Sources/UI/MainWindow/PaneHost.swift` — the modified file
- `Tests/UITests/MainWindowTests/MainWindowTests.swift` — the modified test file
- `docs/roadmap/stevedore-file-browser-bugs/session-02-handoff.md` — Session 02 outcomes

## Tasks
Run every gate below in order. If a gate fails, fix the root cause in the modified files only, then re-run that gate and all subsequent gates from scratch. Do not skip or suppress failures.

1. Full package build with warnings-as-errors:
       swift build -Xswiftc -warnings-as-errors 2>&1 | tail -15

2. Xcode app build (macOS):
       xcodebuild -project Stevedore.xcodeproj -scheme Stevedore -configuration Debug \
         -destination 'platform=macOS' build 2>&1 | tail -10

3. MainWindow unit tests (scoped):
       swift test --filter MainWindowTests 2>&1 | tail -20

4. Full test suite:
       swift test 2>&1 | tail -20

5. SwiftFormat lint (paths before --lint flag):
       swiftformat Sources Tests --lint 2>&1 | grep -v "^$" | tail -20

6. SwiftLint strict:
       swiftlint --strict Sources Tests 2>&1 | tail -20

After all gates pass, write the handoff doc and the go/no-go report.

## Deliverables
- `docs/roadmap/stevedore-file-browser-bugs/session-03-handoff.md` containing:
  - Go/No-Go verdict
  - Output of every gate (pass/fail + counts)
  - Any pre-existing failures noted (do not fix failures outside `touches:` scope)
  - Summary of what changed across the epic

## Exit criteria
- Gates 1, 2, 3, 5, 6 exit 0 with zero new failures.
- Gate 4 may have pre-existing failures from other modules; document them but do not treat them as blockers if they existed before this epic.
- Handoff doc written and contains the go/no-go verdict.
```
