---
session: 28
title: "CI Gate — Final Verification"
depends_on: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27]
touches:
  - .github/workflows/**
  - Makefile
  - docs/ci-report.md
parallel_safe: false
---

# Session 28: CI Gate — Final Verification

Paste this into a new Claude Code session:

```md
Continuity
Continue from every prior session. Read every handoff in `docs/roadmap/stevedore-mvp/`. This session is the final gate — it does not add features.

Mission
Run the full project verification, fix anything red, and codify the gate as a CI workflow so every future change is held to the same bar. Produce a go/no-go report.

Repository anchors
- .github/workflows/ci.yml (GitHub Actions; macOS-14 runner; Xcode + swift toolchain)
- Makefile (top-level convenience targets: `make format-check`, `make lint`, `make build`, `make test`, `make app`, `make ci`)
- docs/ci-report.md (the go/no-go report this session produces)

Tasks
1. Run the full quality-gate matrix from a clean tree:
    - swiftformat --lint Sources Tests App Package.swift
    - swiftlint --strict
    - swift package resolve
    - swift build -Xswiftc -warnings-as-errors
    - swift test --parallel
    - xcodebuild -scheme Stevedore -destination 'platform=macOS' clean build CODE_SIGNING_ALLOWED=NO
2. Iterate on every failure until the entire matrix is green. For each fix, scope changes to the offending module and document the fix in `docs/ci-report.md`. Do not relax linter rules to make a check pass.
3. Cover gaps you observe across handoffs: unimplemented protocol methods, dangling stubs from Session 01 that no module ever filled, type warnings under strict concurrency. File one fix per session of origin and document.
4. Author `Makefile` with the convenience targets and a `make ci` aggregate target wrapping the matrix above.
5. Author `.github/workflows/ci.yml` running the same `make ci` on `macos-14`, with caching for `~/Library/Developer/Xcode/DerivedData`, `.build`, and SwiftPM artifacts. Surface JUnit-style xcresult artifacts on failure.
6. Run `xcodebuild archive` once locally (no signing) to confirm the app target archives cleanly; document the result.
7. Confirm `App/Stevedore.entitlements` is consistent with the capabilities the app actually uses; trim unused entitlements.
8. Produce `docs/ci-report.md` with: matrix results, fixes applied (per session of origin), open issues, and a final go/no-go verdict.

Deliverables
- Workflow file, Makefile, fixes scoped per-module, and the report at `docs/ci-report.md`.
- `docs/roadmap/stevedore-mvp/session-28-handoff.md` summarizing what was fixed, what is still open, and the post-MVP backlog.

Quality gates (must all pass green at session end)
- `make ci`
  → swiftformat --lint Sources Tests App Package.swift
  → swiftlint --strict
  → swift package resolve
  → swift build -Xswiftc -warnings-as-errors
  → swift test --parallel
  → xcodebuild -scheme Stevedore -destination 'platform=macOS' clean build CODE_SIGNING_ALLOWED=NO

Exit criteria
- Every command in `make ci` exits 0 from a clean checkout.
- `docs/ci-report.md` records the green run, the fixes applied, and the explicit "GO" verdict (or "NO-GO" with a list of blocking issues — but the session only ends on GO).
- The CI workflow runs to completion on a fresh GitHub Actions invocation (verified locally via `act` or by pushing a branch).
```
