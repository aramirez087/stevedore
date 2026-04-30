---
session: 01
title: "Charter & Scaffolding"
depends_on: []
touches:
  - Package.swift
  - .swiftlint.yml
  - .swiftformat
  - .gitignore
  - README.md
  - docs/architecture.md
  - Sources/Core/**
  - Sources/FileSystem/**
  - Sources/Services/**
  - Sources/Features/**
  - Sources/UI/**
  - App/**
  - Tests/**
parallel_safe: false
---

# Session 01: Charter & Scaffolding

Paste this into a new Claude Code session:

```md
Mission
Lay the architectural foundation for Stevedore — a native macOS dual-pane file manager modeled on ForkLift. Establish the SwiftPM workspace, module boundaries, protocol stubs, and tooling so subsequent sessions can fan out in parallel without ambiguity.

Repository anchors
- Package.swift (create — Swift tools 6.0, macOS .v14, all module targets, all third-party deps pinned)
- .swiftlint.yml, .swiftformat, .gitignore, README.md (create)
- docs/architecture.md (create — module graph, concurrency model, decisions)
- Sources/Core/{Protocols,Types,Errors,Testing}/*.swift (create types + in-memory test doubles)
- Sources/FileSystem/{Local,Remote,Archive}/Placeholder.swift (create stubs that re-export Core)
- Sources/Services/{Credentials,Settings,Logging}/Placeholder.swift (stub)
- Sources/Features/{Operations,Sync,Rename,Preview,Git,Uninstaller}/Placeholder.swift (stub)
- Sources/UI/{DesignSystem,Pane,Tabs,Sidebar,Toolbar,Transfers,SyncDialog,RenameDialog,ConnectDialog,SettingsUI,UninstallerUI,Menus,MainWindow}/Placeholder.swift (stub)
- App/Stevedore/StevedoreApp.swift (minimal @main App that opens an empty window)
- Tests/<Module>Tests/SmokeTests.swift (one per module — verifies primary type imports and compiles)

Tasks
1. Write Package.swift with Swift tools 6.0, platforms `[.macOS(.v14)]`, strict-concurrency=`complete` for every target. Declare one library target per module directory listed above plus an executable `Stevedore` depending on UI/MainWindow + Features.
2. Pin third-party dependencies up-front so downstream sessions never modify Package.swift: `Citadel` (SFTP), `Soto` (S3 + Core), `ZIPFoundation` (archives), `swift-log` (logging facade). Use latest stable versions. Wire each dep into the relevant module target only.
3. Define protocols in `Sources/Core/Protocols/`: `FileSystemProvider`, `FileEnumeration`, `FileOperationExecutor`, `OperationProgressReporting`, `CredentialStore`, `SettingsStore`, `AppLogger`, `PreviewSource`, `GitStatusProvider`, `ArchiveBrowser`, `RemoteConnector`. Mark `Sendable` where applicable. Document each with a `///` doc comment.
4. Define core types in `Sources/Core/Types/`: `FileItem`, `FilePath`, `FileKind`, `FileAttributes`, `RemoteHostDescriptor`, `ConnectionScheme` (sftp/ftp/webdav/s3/local/smb), `Workspace`, `Tab`, `Bookmark`, `OperationKind`, `OperationDescriptor`, `Progress`. `Sources/Core/Errors/StevedoreError.swift`. Conform Codable types; tests assert encode/decode round-trips.
5. Provide test fakes under `Sources/Core/Testing/`: `InMemoryFileSystemProvider`, `RecordingLogger`, `InMemoryCredentialStore`, `InMemorySettingsStore`. These let UI/feature sessions write tests without depending on concrete services.
6. Write `.swiftlint.yml` (4-space indent, 120 cols, type-name/identifier rules, no force-unwrap, no force-cast). Write `.swiftformat` matching. Write `.gitignore` excluding `.build`, `.swiftpm`, `DerivedData`, `.DS_Store`, `*.xcuserdata`. README documents the build/test loop and common commands.
7. Write `docs/architecture.md` covering: module dependency DAG, concurrency model (actors vs structured concurrency), error handling, logging, and the rationale for each pinned dependency.
8. Write per-module SmokeTests.swift that imports the module and asserts a sentinel value or type alias compiles.

Deliverables
- All files in Repository anchors.
- `docs/roadmap/stevedore-mvp/session-01-handoff.md` listing module surface area, the dependency graph, and any architectural caveats downstream sessions must respect.

Quality gates
- `swift package resolve`
- `swift build`
- `swift test`
- `swiftformat --lint Sources Tests App Package.swift`
- `swiftlint --strict`

Exit criteria
- `swift build` and `swift test` succeed with zero warnings.
- Every module compiles with its placeholder file and an empty implementation surface.
- Test fakes in `Sources/Core/Testing/` let downstream UI sessions construct any view without depending on a concrete provider.
- Architecture doc enumerates every module, dependency, and protocol added in this session.
```
