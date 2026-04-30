---
session: 15
title: "Application Uninstaller Engine"
depends_on: [01, 02, 03]
touches:
  - Sources/Features/Uninstaller/**
  - Tests/FeaturesTests/UninstallerTests/**
parallel_safe: true
---

# Session 15: Application Uninstaller Engine

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 03 artifacts. Read each handoff.

Mission
Identify and (with confirmation upstream) remove the support files left behind by a macOS app — Application Support, Caches, Containers, LaunchAgents, Preferences. Mirror ForkLift's "Application Deleter" feature.

Repository anchors
- Sources/Features/Uninstaller/AppMetadataReader.swift (reads bundleID, name, executable from .app)
- Sources/Features/Uninstaller/AssociatedFilesScanner.swift
- Sources/Features/Uninstaller/SearchPaths.swift (canonical list of macOS user/system locations)
- Sources/Features/Uninstaller/MatchScorer.swift (score files by bundleID/name/exec match)
- Sources/Features/Uninstaller/UninstallPlan.swift
- Sources/Features/Uninstaller/UninstallExecutor.swift (moves to trash via FileManager.trashItem)
- Tests/FeaturesTests/UninstallerTests/*.swift

Tasks
1. `AppMetadataReader`: parse `Contents/Info.plist` of an `.app` bundle for `CFBundleIdentifier`, `CFBundleName`, `CFBundleExecutable`. Validate bundle structure; reject .app paths that don't conform.
2. `SearchPaths` enumerates: `~/Library/Application Support`, `~/Library/Caches`, `~/Library/Containers`, `~/Library/Group Containers`, `~/Library/Preferences`, `~/Library/Saved Application State`, `~/Library/LaunchAgents`, `~/Library/Logs`, `~/Library/HTTPStorages`, `~/Library/WebKit`. Plus their `/Library/...` system equivalents (read-only, present results but never modify without admin escalation).
3. `MatchScorer` computes a confidence score for each candidate path based on substring match of bundleID + bundle name + executable name. High-confidence cutoff configurable.
4. `AssociatedFilesScanner` walks the search paths, applies the scorer, and yields `[AssociatedFile]` with score, size, last-modified, and reason.
5. `UninstallPlan` aggregates the .app bundle + selected associated files. Pure value type.
6. `UninstallExecutor` moves each path to Trash via `FileManager.trashItem(at:resultingItemURL:)` — never `removeItem`. System-owned paths (under `/Library/...`) are reported but not modified.
7. Tests: synthetic app bundle in tmp dir + planted associated files; assert scoring and selection. Trash action verified by checking the source path no longer exists post-execute.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-15-handoff.md` covering the search-path catalog, scoring rules, and safety guarantees (Trash-only, never `rm -rf`).

Quality gates
- `swift build --target FeaturesUninstaller`
- `swift test --filter UninstallerTests`
- `swiftformat --lint Sources/Features/Uninstaller Tests/FeaturesTests/UninstallerTests`
- `swiftlint --strict --path Sources/Features/Uninstaller`

Exit criteria
- Executor uses `trashItem` exclusively — verified by a test that grep-asserts no `removeItem` in the source.
- System-path candidates are returned with `requiresAdmin: true` and skipped during execution.
- Scoring tests cover at least: exact bundleID match, bundle-name substring, executable-name match, and false-positive rejection (e.g., a path containing only a common dictionary word).
```
