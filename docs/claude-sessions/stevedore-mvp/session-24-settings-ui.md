---
session: 24
title: "Settings UI"
depends_on: [01, 02, 07, 08]
touches:
  - Sources/UI/SettingsUI/**
  - Tests/UITests/SettingsUITests/**
parallel_safe: true
---

# Session 24: Settings UI

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 07, 08 artifacts. Read each handoff. Use `import ServicesSettings`, `import DesignSystem`.

Mission
Build the macOS-standard Settings window with tabs (General, Appearance, File Display, Advanced), reading and writing through the `SettingsStore` declared in Session 07.

Repository anchors
- Sources/UI/SettingsUI/SettingsScene.swift (SwiftUI Settings scene)
- Sources/UI/SettingsUI/Tabs/GeneralTab.swift
- Sources/UI/SettingsUI/Tabs/AppearanceTab.swift
- Sources/UI/SettingsUI/Tabs/FileDisplayTab.swift
- Sources/UI/SettingsUI/Tabs/AdvancedTab.swift
- Sources/UI/SettingsUI/Bindings/SettingBinding.swift (typed bridge to SettingsStore)
- Tests/UITests/SettingsUITests/*.swift

Tasks
1. `SettingsScene` declares a `SwiftUI.Settings` scene with four tabs. Tabs use `Form` containers and DesignSystem components only.
2. `SettingBinding` is a generic helper that turns a `Setting<T>` from Session 07 into a SwiftUI `Binding<T>`, observing the store's change stream.
3. **General** tab: default startup behavior (last workspace / blank), default editor command, default terminal app, dual-pane layout default.
4. **Appearance** tab: theme override (system/light/dark), accent color, density (compact/regular).
5. **File Display** tab: hidden files visibility, byte-size formatting (binary/decimal), date format (relative/absolute), default sort key + direction.
6. **Advanced** tab: log level, ring-buffer size, conflict-policy default, transfer concurrency cap.
7. Each setting writes immediately on change (no Apply button) and is observable elsewhere — verified by tests that mutate the store and assert the binding emits.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-24-handoff.md` mapping every UI control to the underlying `Setting<T>` key.

Quality gates
- `swift build --target UISettingsUI`
- `swift test --filter SettingsUITests`
- `swiftformat --lint Sources/UI/SettingsUI Tests/UITests/SettingsUITests`
- `swiftlint --strict --path Sources/UI/SettingsUI`

Exit criteria
- Every control corresponds to a declared setting in `Settings+Catalog.swift` (no orphan keys).
- Settings UI tests run against an `InMemorySettingsStore` and require zero file-system I/O.
- Theme override is applied immediately to the Settings window itself — verified visually via SwiftUI preview.
```
