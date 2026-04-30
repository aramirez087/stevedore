# Stevedore

A native macOS dual-pane file manager modeled on BinaryNights ForkLift. Built with
Swift 6 and SwiftUI, targeting macOS 14+.

## Status

Pre-MVP. Module skeleton and tooling are in place; concrete providers, services,
features, and UI ship in subsequent sessions. See `docs/architecture.md` for the
module catalog and `docs/roadmap/stevedore-mvp/` for session handoffs.

## Requirements

- macOS 14.0 or newer (Apple Silicon or Intel)
- Xcode 16 / Swift 6.0+ toolchain
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) and
  [SwiftLint](https://github.com/realm/SwiftLint) for the lint gates:

  ```sh
  brew install swiftformat swiftlint
  ```

## Build & test

The Swift Package Manager workspace at the repo root is authoritative.

```sh
swift package resolve     # fetch pinned dependencies
swift build               # build all targets
swift test                # run all test targets
swift run Stevedore       # launch the (currently empty) app
```

To work in Xcode, open `Package.swift` directly:

```sh
open Package.swift
```

A generated Xcode project at `App/Stevedore.xcodeproj` is git-ignored and used
only by CI for archiving; never hand-edit it.

## Quality gates

Before committing, run:

```sh
swift build -Xswiftc -warnings-as-errors
swift test
swiftformat --lint Sources Tests App Package.swift
swiftlint --strict
```

## Module map

| Path                          | Target              |
|-------------------------------|---------------------|
| `Sources/Core`                | `Core`              |
| `Sources/FileSystem/Local`    | `FileSystemLocal`   |
| `Sources/FileSystem/Remote`   | `FileSystemRemote`  |
| `Sources/FileSystem/Archive`  | `FileSystemArchive` |
| `Sources/Services/Credentials`| `ServicesCredentials` |
| `Sources/Services/Settings`   | `ServicesSettings`  |
| `Sources/Services/Logging`    | `ServicesLogging`   |
| `Sources/Features/*`          | `Features<Name>`    |
| `Sources/UI/DesignSystem`     | `DesignSystem`      |
| `Sources/UI/<Other>`          | `UI<Name>`          |
| `Sources/UI/MainWindow`       | `MainWindow`        |
| `App/Stevedore`               | `Stevedore` (executable) |

See `docs/architecture.md` for the full dependency graph, concurrency model,
error-handling strategy, and rationale for each pinned third-party dependency.

## License

TBD.
