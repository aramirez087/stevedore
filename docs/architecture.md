# Stevedore Architecture

## 1. Overview

Stevedore is a native macOS dual-pane file manager modeled on BinaryNights
ForkLift. It is a Swift 6 / SwiftUI application targeting macOS 14.0+ on
Apple Silicon and Intel. The MVP scope: local + remote file browsing
(SFTP, FTP, WebDAV, S3), copy/move/sync/rename/preview/uninstall/git-status
features, with all secrets stored in the macOS Keychain and all file work
happening off the main actor.

This document is the canonical reference for module boundaries, the
concurrency model, and the rationale for each pinned third-party
dependency. Downstream sessions cite section numbers when justifying where
new code lands.

## 2. Module catalog

| Path                          | Target              | Depends on (extra)             | Responsibility |
|-------------------------------|---------------------|--------------------------------|----------------|
| `Sources/Core`                | `Core`              | —                              | Protocols, value types, errors, in-memory test fakes. The vocabulary every other module shares. |
| `Sources/FileSystem/Local`    | `FileSystemLocal`   | —                              | `FileSystemProvider` over the local disk. |
| `Sources/FileSystem/Remote`   | `FileSystemRemote`  | `Citadel`, `SotoS3`            | SFTP, FTP, WebDAV, S3 providers + `RemoteConnector`. |
| `Sources/FileSystem/Archive`  | `FileSystemArchive` | `ZIPFoundation`                | `ArchiveBrowser` for .zip / .tar / .tar.gz / .tar.bz2. |
| `Sources/Services/Credentials`| `ServicesCredentials` | —                            | Keychain-backed `CredentialStore`. |
| `Sources/Services/Settings`   | `ServicesSettings`  | —                              | `UserDefaults`-backed `SettingsStore`. |
| `Sources/Services/Logging`    | `ServicesLogging`   | `swift-log`                    | `AppLogger` bridge to `swift-log` + `os.Logger`. |
| `Sources/Features/Operations` | `FeaturesOperations`| —                              | Operation queue, executor, conflict policy resolution. |
| `Sources/Features/Sync`       | `FeaturesSync`      | —                              | Directory comparison + sync engine. |
| `Sources/Features/Rename`     | `FeaturesRename`    | —                              | Batch rename pipeline. |
| `Sources/Features/Preview`    | `FeaturesPreview`   | —                              | Quick Look + first-party preview renderers. |
| `Sources/Features/Git`        | `FeaturesGit`       | —                              | `git status --porcelain=v2` wrapper. |
| `Sources/Features/Uninstaller`| `FeaturesUninstaller` | —                            | App-uninstaller engine. |
| `Sources/UI/DesignSystem`     | `DesignSystem`      | —                              | Colors, typography, spacing, control styles. |
| `Sources/UI/Pane`             | `UIPane`            | —                              | File list / tree views. |
| `Sources/UI/Tabs`             | `UITabs`            | —                              | Pane tab strip. |
| `Sources/UI/Sidebar`          | `UISidebar`         | —                              | Bookmarks + remote hosts. |
| `Sources/UI/Toolbar`          | `UIToolbar`         | —                              | Main window toolbar. |
| `Sources/UI/Transfers`        | `UITransfers`       | —                              | Transfers / queue panel. |
| `Sources/UI/SyncDialog`       | `UISyncDialog`      | —                              | Synchronize dialog. |
| `Sources/UI/RenameDialog`     | `UIRenameDialog`    | —                              | Batch rename dialog. |
| `Sources/UI/ConnectDialog`    | `UIConnectDialog`   | —                              | Remote-connect dialog. |
| `Sources/UI/SettingsUI`       | `UISettingsUI`      | —                              | Preferences window. |
| `Sources/UI/UninstallerUI`    | `UIUninstallerUI`   | —                              | App-uninstaller dialog. |
| `Sources/UI/Menus`            | `UIMenus`           | —                              | Menu-bar commands. |
| `Sources/UI/MainWindow`       | `MainWindow`        | —                              | Root window scene + composition root. |
| `App/Stevedore`               | `Stevedore` (exec)  | `Core`, `MainWindow`           | `@main` shell. |

Every non-`Core` library target depends on `Core`. The matrix above lists
*extra* dependencies beyond that baseline.

## 3. Dependency DAG

```
Core
  ├── FileSystemLocal
  ├── FileSystemRemote      (+ Citadel, SotoS3)
  ├── FileSystemArchive     (+ ZIPFoundation)
  ├── ServicesCredentials
  ├── ServicesSettings
  ├── ServicesLogging       (+ swift-log)
  ├── FeaturesOperations
  ├── FeaturesSync
  ├── FeaturesRename
  ├── FeaturesPreview
  ├── FeaturesGit
  ├── FeaturesUninstaller
  ├── DesignSystem
  ├── UIPane
  ├── UITabs
  ├── UISidebar
  ├── UIToolbar
  ├── UITransfers
  ├── UISyncDialog
  ├── UIRenameDialog
  ├── UIConnectDialog
  ├── UISettingsUI
  ├── UIUninstallerUI
  ├── UIMenus
  └── MainWindow

Stevedore (executable) → Core, MainWindow
```

Session 01 keeps every leaf module pointing only at `Core`. Cross-module
edges (e.g., `UIPane → DesignSystem`) belong to the session that introduces
the consuming code; introducing them now would force a `Package.swift` edit
in a later session, violating the "Package.swift frozen after Session 01"
rule.

## 4. Concurrency model

- **Actors** own mutable state with I/O affinity: provider implementations,
  the operation queue, remote sessions, the keychain store, the ring-buffer
  logger, and every in-memory test fake under `Sources/Core/Testing/`.
- **Structured concurrency** (`async let`, `TaskGroup`,
  `AsyncThrowingStream`, `AsyncStream`) for cancellable streaming work —
  directory enumeration, filesystem watching, sync comparison.
- **`@MainActor`** for SwiftUI view-models in downstream UI sessions. The
  Core protocols compose with main-actor bindings because every method is
  declared `async` and every callback type is `Sendable`.
- **All public types `Sendable`**. `Codable` value types are auto-Sendable;
  reference types are `final` and explicit. `@unchecked Sendable` is
  forbidden in Session 01.
- Callbacks use `@Sendable` closures; long-running observation uses
  `AsyncStream` / `AsyncThrowingStream` rather than delegate patterns.

The package enables strict-concurrency checking
(`-enable-experimental-feature StrictConcurrency`) and Swift 6 language
mode for every target.

## 5. Error model

`StevedoreError` is the root error type. Every public-facing API surfaces
failures through this tree so the UI can route uniformly to dialogs and
the logger.

```
StevedoreError
├── .fileSystem(FileSystemError)
├── .remote(RemoteError)
├── .archive(ArchiveError)
├── .credential(CredentialError)
├── .settings(SettingsError)
├── .cancelled
├── .invalidArgument(String)
└── .unsupported(String)
```

Each leaf enum is `LocalizedError` (so `errorDescription` is dialog-ready)
and `Sendable & Hashable`. `StevedoreError.category` returns a
`LogCategory` so the logger can tag every routed error consistently.

Propagation rule: subsystems never throw foreign error types across a
module boundary. Bridging to `StevedoreError` happens at the
`FileSystemProvider` / `RemoteConnector` / `ArchiveBrowser` /
`CredentialStore` / `SettingsStore` boundary.

## 6. Logging model

`AppLogger` is the uniform facade across the app. Concrete implementations
live in `ServicesLogging` and bridge to `swift-log` + `os.Logger`. Log
sites pass:

- a `LogLevel` (trace / debug / info / notice / warning / error / critical);
- an `@autoclosure @Sendable` message so formatting only runs when the level
  passes;
- a `LogCategory` (`.fileSystem`, `.remote`, `.archive`, `.credentials`,
  `.settings`, `.operations`, `.sync`, `.rename`, `.preview`, `.git`,
  `.uninstaller`, `.ui`, `.app`, `.unknown`);
- optional metadata `[String: String]`.

`StevedoreError.category` maps each leaf error to a `LogCategory`, so
"log this caught error" is a single helper away in downstream sessions.

## 7. Testing strategy

Every library target ships at least one smoke test under
`Tests/<Module>Tests/`. The smoke test imports the module and asserts the
sentinel `<ModuleName>Module.moduleName` constant — this guarantees that
every module is link-clean from its test target.

Core ships three test suites:

1. `CoreSmokeTests` — exercises the primary value-type behavior
   (`FilePath` normalization, `FileItem` display name, `StevedoreError`
   category mapping).
2. `CodableRoundTripTests` — encodes and decodes every persisted Codable
   type (`FilePath`, `FileItem`, `RemoteHostDescriptor`, `OperationKind`
   including the `.archive(format:)` variant, `OperationDescriptor`,
   `Workspace`, `Bookmark`, `Credential` for both password and private-key
   materials, `Progress`, `GitFileStatus`).
3. `InMemoryFakesTests` — verifies each Core fake conforms to its
   protocol (`AppLogger`, `CredentialStore`, `SettingsStore`,
   `FileSystemProvider`) and behaves as advertised.

Downstream feature / UI sessions construct view-models and engines using
the four fakes under `Sources/Core/Testing/` and so do not depend on
concrete services to write tests.

## 8. Third-party dependencies

Pinned in `Package.swift` at the root; downstream sessions never modify
the dependency list.

| Package           | Purpose                                                          | Pin        | Used by              |
|-------------------|------------------------------------------------------------------|------------|----------------------|
| Citadel           | Pure-Swift SSH / SFTP client, NIO-native, async/await API        | 0.7.0+     | `FileSystemRemote`   |
| Soto (SotoS3)     | AWS S3 client; we only use the S3 sub-product, not the whole SDK | 7.0.0+     | `FileSystemRemote`   |
| ZIPFoundation     | Pure-Swift ZIP read/write; foundation for archive browsing       | 0.9.19+    | `FileSystemArchive`  |
| swift-log         | Logging facade; pairs with `os.Logger` for unified destinations  | 1.6.0+     | `ServicesLogging`    |

Resolved versions for Session 01 (recorded in `Package.resolved`):
Citadel 0.12.1, Soto 7.14.0, ZIPFoundation 0.9.20, swift-log 1.12.0.
NIO and other transitive packages resolve through these.

Rationale for each pin:

- **Citadel** is the only pure-Swift SFTP client with a modern async/await
  API and macOS-friendly NIO backend. libssh2-based alternatives require
  C-bridging, manual buffer management, and don't compose with structured
  concurrency.
- **SotoS3** is the actively maintained Swift S3 client. We pin to the v7
  major line for Swift Concurrency–native APIs.
- **ZIPFoundation** is the standard Swift ZIP library. tar / tar.gz /
  tar.bz2 wrappers will be authored on top of it in a downstream session.
- **swift-log** is Apple's official logging facade; bridging to it lets
  third-party logging back-ends slot in without touching the call sites.

## 9. Decisions logged in Session 01

- Protocols and value types live in `Core`. Every module imports `Core`.
  No `@_exported` re-exports; placeholder files use a plain `import Core`
  plus a marker namespace (`<ModuleName>Module.moduleName`).
- `FilePath` is a Stevedore-native value type, not `Foundation.FilePath`,
  because remote schemes have different normalization semantics and
  `Foundation.FilePath` does not carry a transport tag.
- `Progress` is a Stevedore-native struct rather than `Foundation.Progress`
  so it can be `Sendable` and `Codable` without inheriting `NSObject`.
- `OperationKind.archive(format:)` and `Credential.Material` ship hand-rolled
  `Codable` implementations with an explicit discriminator field; this
  keeps the persisted form forward-compatible.
- `FileSystemProvider.enumerate` returns
  `AsyncThrowingStream<FileItem, any Error>` rather than a constrained
  existential `any FileEnumeration`. `AsyncSequence` requires both
  `Element` and `Failure` primary-associated-types when written as
  `AsyncSequence<Element, Failure>`, but the `Failure` primary is only
  available on macOS 15+. Because Stevedore targets macOS 14.0, we cannot
  bind both via the existential. `AsyncThrowingStream` is concrete,
  ergonomic, and works on macOS 14. The `FileEnumeration` protocol is
  retained as a marker so providers may still publish typed
  `AsyncSequence` enumerators internally.
- Codable-persisted types use only primitive Swift types (`String`, `Int`,
  `Int64`, `Date`, `[String]`, `enum`, `UUID`) so coding is mechanical and
  Sendable-clean across the wire.
- Test fakes live in `Sources/Core/Testing/` (production target), not in
  a separate test-only target, so downstream feature and UI sessions can
  depend on them without depending on an XCTest binary.
- Smoke-test files are uniquely named per module (e.g.
  `FileSystemLocalSmokeTests.swift`) because SwiftPM produces one `.o` per
  source basename within a target — duplicate `SmokeTests.swift` files
  collide at link time.

## 10. Public protocol surface (Session 01)

Defined in `Sources/Core/Protocols/` and re-stated here as the canonical
reference. Downstream sessions extend implementations but should not need
to widen these protocols. If they do, that signals a design miss to record
in the session handoff.

```
FileSystemProvider                 // root abstraction for any file source
FileEnumeration                    // marker AsyncSequence<FileItem>-shaped
FileOperationExecutor              // primitive op runner
OperationProgressReporting         // progress callback type
CredentialStore                    // Keychain + in-memory facade
SettingsStore                      // typed settings + observation
AppLogger                          // uniform logging facade
PreviewSource                      // Quick Look + first-party renderer
GitStatusProvider                  // porcelain v2 wrapper
ArchiveBrowser                     // zip / tar / tar.gz / tar.bz2 reader
RemoteConnector                    // session opener + tester for remote hosts
```

## 11. Public type surface (Session 01)

Defined in `Sources/Core/Types/` (and `Sources/Core/Errors/` for the error
tree).

```
FilePath, FileKind, FileAttributes, PosixPermissions, FileItem
ConnectionScheme, RemoteHostDescriptor, ConnectionTestResult
EnumerationOptions, FilePathChange
OperationKind, ArchiveFormat, ConflictPolicy, OperationDescriptor, OperationResult
Progress (incl. Phase)
Bookmark, Tab, Workspace (incl. Workspace.Pane)
Credential (incl. Credential.Material), Setting<Value>
LogLevel, LogCategory, PreviewPayload, GitFileStatus

StevedoreError, FileSystemError, RemoteError, ArchiveError, CredentialError, SettingsError
```

Every persisted type conforms to `Codable & Sendable & Hashable`; every
type is `Sendable` regardless of whether it persists.
