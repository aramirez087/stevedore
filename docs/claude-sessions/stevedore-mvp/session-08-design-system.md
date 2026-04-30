---
session: 08
title: "Design System"
depends_on: [01]
touches:
  - Sources/UI/DesignSystem/**
  - Tests/UITests/DesignSystemTests/**
parallel_safe: true
---

# Session 08: Design System

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01 artifacts. Read `docs/roadmap/stevedore-mvp/session-01-handoff.md`. The DesignSystem target exists with a placeholder; downstream UI sessions will import `import DesignSystem`.

Mission
Provide the visual building blocks every UI session reuses — color tokens, typography, spacing, icon registry, and a small library of atomic SwiftUI views — so the dual-pane shell stays consistent and theme-aware.

Repository anchors
- Sources/UI/DesignSystem/Theme/ColorTokens.swift
- Sources/UI/DesignSystem/Theme/Typography.swift
- Sources/UI/DesignSystem/Theme/Spacing.swift
- Sources/UI/DesignSystem/Theme/Theme.swift (Environment-injected)
- Sources/UI/DesignSystem/Icons/IconRegistry.swift (SF Symbols + filetype mapping)
- Sources/UI/DesignSystem/Icons/FileKindIcon.swift
- Sources/UI/DesignSystem/Components/SDButton.swift
- Sources/UI/DesignSystem/Components/SDTextField.swift
- Sources/UI/DesignSystem/Components/SDSearchField.swift
- Sources/UI/DesignSystem/Components/SDProgressBar.swift
- Sources/UI/DesignSystem/Components/SDListRow.swift
- Sources/UI/DesignSystem/Components/SDLabel.swift
- Sources/UI/DesignSystem/Previews/* (SwiftUI previews for each component, light + dark)
- Tests/UITests/DesignSystemTests/*.swift

Tasks
1. Define semantic color tokens (background, surface, surface-elevated, text-primary, text-secondary, accent, danger, success, divider) resolving to NSColor dynamic colors that auto-adapt to light/dark.
2. Typography scale (`largeTitle`, `title`, `body`, `caption`, `mono`) bound to system fonts; mono uses SF Mono.
3. Spacing tokens (`xs`, `sm`, `md`, `lg`, `xl`) as `CGFloat` constants. No hard-coded numerics elsewhere in UI sessions.
4. `Theme` is a struct injected via `EnvironmentValue`; default is system theme. Settings session will later bind a user override here — leave the API stable.
5. Icon registry maps `FileKind` and extension to an SF Symbol; falls back to `doc` for unknown. Provide `FileKindIcon` SwiftUI view that renders the icon at size `IconSize` (sm/md/lg).
6. Atomic components: button, textfield, search field, progress bar, list row (one-line + two-line), label. Each has SwiftUI previews showing light/dark/all states.
7. Tests: snapshot-style assertions on token values; smoke tests that each component renders without crashing using `ViewInspector` only if pinned (otherwise hosting in `NSHostingView` and asserting non-nil).

Deliverables
- All source files plus previews.
- `docs/roadmap/stevedore-mvp/session-08-handoff.md` documenting the token palette and component API surface so downstream UI sessions never reach for raw NSColor or hard-coded paddings.

Quality gates
- `swift build --target DesignSystem`
- `swift test --filter DesignSystemTests`
- `swiftformat --lint Sources/UI/DesignSystem Tests/UITests/DesignSystemTests`
- `swiftlint --strict --path Sources/UI/DesignSystem`

Exit criteria
- Every component has a working SwiftUI preview in both light and dark mode.
- No public API exposes raw `Color` literals or hard-coded fonts — only tokens.
- Components are deterministic given the same inputs (no implicit `@StateObject` randomness).
```
