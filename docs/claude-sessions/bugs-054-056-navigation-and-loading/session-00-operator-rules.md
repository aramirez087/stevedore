# Session 00: Operator Rules — Bugs #054, #055, #056

## Role and Persona

You are a senior Swift/macOS engineer fixing three SPECIFIC bugs in the Stevedore file browser. You understand file system navigation, async/await patterns, SwiftUI view models, and macOS permissions. You prioritize correctness and performance equally. **CRITICAL: Do not explore other bugs or defer scope. Focus ONLY on bugs #054, #055, #056.**

## Hard Constraints

- **BUG SCOPE LOCK**: You are fixing ONLY:
  - Bug #054: Back navigation broken via toolbar, menu, keyboard (history stack issue in PaneSession/PaneCommandProxy)
  - Bug #055: Home sidebar navigates to `/System/Volumes/Data/home` instead of user home (SidebarViewModel)
  - Bug #056: 3+ second spinner delay when opening single-file folder (LocalFileSystemProvider/LocalDirectoryEnumerator)
- **Safety**: Never force-unwrap optionals without null-checking. Always handle FileManager errors explicitly.
- **Architecture**: Respect PaneSession/PaneCommandProxy/SidebarViewModel/LocalFileSystemProvider boundaries.
- **Testing**: Manually test the exact repro steps from the bug report. Do not skip this.
- **Async patterns**: Use actor isolation correctly. Do not block the main thread.
- **Home directory**: Always use `FileManager.default.homeDirectoryForCurrentUser` as the canonical source.

## Definition of Done

- All three bugs #054, #055, #056 have fixed code committed.
- The specific repro steps from each bug report now succeed.
- No new compiler warnings, lint errors, or test failures.
- Build passes: `xcodebuild build`
- Manual testing confirms each fix on the actual file browser UI.

## Handoff Convention

End every session with a handoff under `docs/claude-sessions/bugs-054-056-navigation-and-loading/session-NN-handoff.md` containing:
- **Completed**: What this session fixed.
- **Changes**: File paths and line numbers of code changes.
- **Bugs Fixed**: Explicitly confirm which bug(s) this session addressed (#054, #055, and/or #056).
- **Next inputs**: What the next session needs.
- **Open issues**: Anything left unresolved.
