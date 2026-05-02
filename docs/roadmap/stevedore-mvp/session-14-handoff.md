# Session 14 Handoff — Git Status Integration

## Scope

Surface git working-tree status decorations by shelling out to `/usr/bin/git` via porcelain v2
NUL-delimited output. All results are cached per-repo and invalidated by FSEvents within 50ms
latency. No libgit2 or other native git dependency is introduced. The session is confined to
`Sources/Features/Git/` and `Tests/FeaturesTests/GitTests/`.

## What changed

### Sources/Features/Git/ (7 files added / placeholder replaced)

- `FeaturesGitModule.swift` — replaced placeholder; preserves `FeaturesGitModule.moduleName`
  sentinel consumed by the pre-existing smoke test.
- `GitError.swift` — typed errors: `gitNotFound`, `timeout`, `nonZeroExit(code:)`,
  `parseFailure`.
- `GitProcess.swift` — stateless `public enum` (all-static) git process runner. Runs
  `/usr/bin/git` with a whitelisted environment (`HOME`, `USER`, `TMPDIR`, `LANG`, `LC_ALL`,
  `GIT_SSH`, `GIT_SSH_COMMAND`, `SSH_AUTH_SOCK`) and always injects `GIT_TERMINAL_PROMPT=0`,
  `GIT_PAGER=cat`, `PAGER=cat`. Two-task `withThrowingTaskGroup` implements a hard timeout;
  `Foundation.Process` is wrapped in a `ProcessBox: @unchecked Sendable` heap class
  (single-owner, justified comment).
- `RepositoryDetector.swift` — ancestor-walk repo detection. `.git` as a directory → normal
  repo; `.git` as a file → git worktree linkfile; neither → `nil`. Non-`.local` scheme
  returns `nil` immediately.
- `GitStatusParser.swift` — NUL-delimited porcelain v2 parser. Splits data on `\0` into a
  flat token array and processes with an integer cursor. Type-2 (renamed/copied) records
  consume two tokens. Unknown prefixes are silently skipped; the parser never throws. All
  paths are relative to repo root; `repoRoot.appending(posix:)` builds absolute `FilePath`.
- `GitStatusCache.swift` — `public actor` with per-repo `CacheEntry` keyed by repo root
  `FilePath`. `CacheEntry` holds `statuses`, a `hasFetched` sentinel (distinguishes empty
  result from cold cache), `watchTask`, and `fetchTask` for coalescing concurrent fetches.
  FSEvents stream created with 50ms latency and `kFSEventStreamCreateFlagFileEvents |
  kFSEventStreamCreateFlagUseCFTypes`. Callback dispatched via `CallbackPayload`
  (`@unchecked Sendable`, weak cache reference) and `StreamBox` (holds `FSEventStreamRef?`
  for `@Sendable` capture in `onCancel`).
- `GitStatusService.swift` — concrete `public actor` conforming to `Core.GitStatusProvider`.
  `status(under:)`: detect repo root → `cache.getOrFetch` → filter by directory prefix.
  Runs `git status --porcelain=v2 -z --untracked-files=all --ignored=matching`.

### Tests/FeaturesTests/GitTests/ (6 files added)

- `GitTestSupport.swift` — `skipIfGitMissing()` helper (throws `XCTSkip` when
  `/usr/bin/git` absent); `GitTestRepo` fixture with `create`, `tearDown`, `makeFile`,
  `makeAndStage`, `commit`, `modifyFile`, `deleteFile`, `addToGitignore`.
- `GitProcessTests.swift` — 5 tests: version, non-zero exit outside repo, env isolation,
  timeout, stdout/stderr capture.
- `RepositoryDetectorTests.swift` — 5 tests: from subdirectory, at root, outside repo,
  worktree linkfile, non-local scheme.
- `GitStatusParserTests.swift` — 15 tests: all porcelain v2 status codes, multiple entries,
  copied record, unknown prefix skip.
- `GitStatusCacheTests.swift` — 5 tests: cache hit, manual invalidation,
  miss-after-invalidate, FSEvents invalidation timing (250ms sleep), concurrent fetch
  coalescing.
- `GitStatusProviderTests.swift` — 11 integration tests: clean repo, dirty file, staged
  file, deleted file, staged deletion, renamed file, untracked file, ignored file, root
  resolution, non-git directory, subdirectory filter.

## Decisions

- **`GitProcess` is `public enum` (all-static)** — satisfies SwiftLint `no_empty_class`
  rule; a namespace-only type with no instances.
- **`ProcessBox: @unchecked Sendable`** — wraps non-`Sendable` `Foundation.Process`; the
  box is single-owner and never accessed concurrently after launch, making the unsafety
  sound. Comment in source justifies this.
- **50ms FSEvents latency** — keeps cache invalidation well within the 200ms exit criterion
  even under load; `testFSEventsInvalidation` sleeps 250ms to give headroom.
- **`hasFetched` sentinel in `CacheEntry`** — distinguishes "fetched, empty result" from
  "never fetched". This was identified as a bug in the Session 01 carry-over
  (`GitStatusCache.getOrFetch` used `!statuses.isEmpty` as hit guard, always re-fetching
  empty repos) and is correctly fixed here.
- **`--untracked-files=all --ignored=matching`** — makes untracked and ignored files
  visible in every subdirectory, not just the root of each untracked tree.
- **Parser skips unknown prefixes silently** — forward-compatible with future git versions
  adding new `git status --porcelain=v2` record types.
- **`CallbackPayload` weak reference** — `FSEventStreamRef` C callback cannot close over an
  actor directly; `CallbackPayload` holds `weak var cache` so the callback doesn't extend
  the actor's lifetime past deallocation.

## Open issues / risks

1. **`--ignored=matching` output volume** — on repos with many ignored files, the porcelain
   v2 output can be large. Not a concern for MVP file-pane status badges, but callers
   implementing non-decoration use cases should consider `--ignored=no`.
2. **FSEvents timing test may be flaky on heavily loaded CI** — `testFSEventsInvalidation`
   has a 250ms sleep for a 50ms-latency stream. On very slow machines this could still race.
   Inherent to the 200ms real-time exit criterion.
3. **Bare repositories return `nil` from `RepositoryDetector`** — acceptable for MVP.
   Distinguishing a bare repo would require `git rev-parse --is-bare-repository`; deferred.
4. **Submodule recursive status deferred** — submodule paths are reported at the submodule
   boundary only; recursive status within submodules requires a separate `git status` call
   per submodule working tree.
5. **Stage/commit/push/pull are intentionally absent** — `Core.GitStatusProvider` has no
   mutation surface. A separate `GitCommandProvider` protocol would be needed in a later
   session.

## Next-session inputs

- **Session 16 (File Pane View)**: import `FeaturesGit`; inject `GitStatusService` via the
  `Core.GitStatusProvider` protocol (not the concrete type) so tests can use a fake. Call
  `service.repositoryRoot(for:)` once per directory navigation to decide whether to show
  git badges. Call `service.status(under:)` to decorate `FileItem` rows.
- **`GitFileStatus.WorktreeState` cases**: `unmodified`, `modified`, `added`, `deleted`,
  `renamed`, `copied`, `untracked`, `ignored`, `typeChanged`, `conflicted`.
- **`GitFileStatus.IndexState` cases**: same set — read both for a complete two-column
  status display if desired (index vs. worktree).
- **Cache invalidation is automatic** — after the first `status(under:)` call per repo,
  FSEvents keeps the cache fresh. Callers do not need to call `invalidate` manually.
- **`--filter` note for test runners**: `GitTests` does not match the XCTest filter syntax
  because the test classes live in the `FeaturesTests` module target. Use
  `--filter "GitProcessTests|GitStatusCacheTests|GitStatusParserTests|GitStatusProviderTests|RepositoryDetectorTests"`.

## Verification

All commands run from the worktree root.

```
swift build --target FeaturesGit
→ Build of target: 'FeaturesGit' complete! (0 warnings, 13.78s)

swift build --target FeaturesGit \
    -Xswiftc -strict-concurrency=complete \
    -Xswiftc -warnings-as-errors
→ Build of target: 'FeaturesGit' complete! (0 warnings, 4.92s)

swift test --filter "GitProcessTests|GitStatusCacheTests|GitStatusParserTests|GitStatusProviderTests|RepositoryDetectorTests"
→ Executed 43 tests, with 0 failures (0 unexpected)
  (GitProcessTests: 5, GitStatusParserTests: 15, GitStatusCacheTests: 5,
   GitStatusProviderTests: 11, RepositoryDetectorTests: 5, GitTestSupport: support only)

swiftformat Sources/Features/Git Tests/FeaturesTests/GitTests --lint
→ 0/13 files require formatting

swiftlint lint --strict Sources/Features/Git
→ Done linting! Found 0 violations, 0 serious in 294 files.
```
