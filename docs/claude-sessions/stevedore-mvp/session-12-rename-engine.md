---
session: 12
title: "Multi-Rename Engine"
depends_on: [01, 02, 03]
touches:
  - Sources/Features/Rename/**
  - Tests/FeaturesTests/RenameTests/**
parallel_safe: true
---

# Session 12: Multi-Rename Engine

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 03 artifacts. Read each handoff. Use Core utilities for path manipulation.

Mission
Provide a batch rename engine — given a list of `FileItem`s and a recipe, produce the planned target names with conflict detection, then execute them via a `FileSystemProvider`.

Repository anchors
- Sources/Features/Rename/RenameRecipe.swift (composed steps)
- Sources/Features/Rename/RenameStep.swift (find/replace, case, sequence numbering, trim, insert, regex, EXIF metadata)
- Sources/Features/Rename/RenamePlanner.swift (pure: takes inputs + recipe → planned targets)
- Sources/Features/Rename/RenameExecutor.swift (drives a provider; rolls back on partial failure)
- Sources/Features/Rename/CollisionResolver.swift
- Tests/FeaturesTests/RenameTests/*.swift

Tasks
1. `RenameStep` enum cases: `find(text, replace, caseSensitive)`, `regex(pattern, replacement)`, `case(.lower|.upper|.title|.preserve)`, `sequence(start, padding, position)`, `trim(.leading|.trailing|.both)`, `insert(text, at: position)`, `extension(.lower|.upper|.preserve)`.
2. `RenameRecipe` orders a list of steps; planner applies them deterministically. Original name + index are inputs; output is the new name.
3. `RenamePlanner.plan(items:recipe:)` returns `[RenameOutcome]` (source path, target name, status: ok | collision | invalid). Pure function; thoroughly unit-tested.
4. `CollisionResolver`: detects target-name collisions within the batch and against existing siblings; offers auto-suffix or marks invalid.
5. `RenameExecutor` takes a `FileSystemProvider` and a planned list, performs `rename` ops, and on any failure attempts to roll back already-applied renames using a journal.
6. Tests: every step type with edge cases (Unicode normalization, very long names, regex backreferences, sequence padding boundaries), collision detection, rollback after injected failure.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-12-handoff.md` covering recipe semantics, collision rules, and the API the Rename dialog will use to preview + commit.

Quality gates
- `swift build --target FeaturesRename`
- `swift test --filter RenameTests`
- `swiftformat --lint Sources/Features/Rename Tests/FeaturesTests/RenameTests`
- `swiftlint --strict --path Sources/Features/Rename`

Exit criteria
- Planner is pure and deterministic — given the same inputs and recipe, output is identical across runs.
- Rollback test injects a failure on the 5th rename of 10 and asserts the first 4 are reversed and the remaining 5 untouched.
- Regex step rejects malformed patterns at planning time, not at execution.
```
