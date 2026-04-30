---
session: 14
title: "Git Status Integration"
depends_on: [01, 02, 03]
touches:
  - Sources/Features/Git/**
  - Tests/FeaturesTests/GitTests/**
parallel_safe: true
---

# Session 14: Git Status Integration

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 03 artifacts. Read each handoff.

Mission
Surface git status decorations in the file pane — each file's working-tree status (modified, added, deleted, untracked, ignored) — by shelling out to `/usr/bin/git`. No native libgit2 dependency in the MVP.

Repository anchors
- Sources/Features/Git/GitStatusProvider.swift (concrete impl of Core protocol)
- Sources/Features/Git/GitProcess.swift (typed wrapper over Foundation Process)
- Sources/Features/Git/GitStatusParser.swift (parses `git status --porcelain=v2 -z`)
- Sources/Features/Git/RepositoryDetector.swift (walk up to find .git)
- Sources/Features/Git/GitStatusCache.swift (per-repo, invalidated by FSEvents)
- Tests/FeaturesTests/GitTests/*.swift (uses tmp git repos)

Tasks
1. `GitProcess` runs `git` with a fixed env and timeout; returns stdout/stderr/exit. Never inherits the calling shell env beyond what's whitelisted.
2. `RepositoryDetector` walks parents from a `FilePath` to find `.git`; handles bare repos and worktrees.
3. `GitStatusParser`: parse porcelain v2 NUL-delimited output into `[GitFileStatus]` entries; handle renames, untracked, ignored, submodules.
4. `GitStatusProvider` returns status for files under a directory; results cached per-repo and invalidated by FSEvents on `.git/HEAD`, `.git/index`, or any path under the worktree.
5. Out of MVP scope: stage/commit/push/pull. Leave protocol hooks for the future but do not implement.
6. Tests: spin up a real git repo in a tmp dir using `GitProcess`, perform working-tree edits, assert status output. Coverage for: clean repo, dirty file, staged file, deleted file, renamed file, untracked, ignored, submodule.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-14-handoff.md` documenting the porcelain parser surface, cache invalidation rules, and what is intentionally deferred.

Quality gates
- `swift build --target FeaturesGit`
- `swift test --filter GitTests`
- `swiftformat --lint Sources/Features/Git Tests/FeaturesTests/GitTests`
- `swiftlint --strict --path Sources/Features/Git`

Exit criteria
- Tests skip cleanly with a clear `XCTSkip` if `/usr/bin/git` is missing.
- Cache is invalidated within 200ms of a tracked-file modification — verified with a timing test.
- Parser handles every status code listed in `git-status(1)` porcelain v2 (covered by fixtures).
```
